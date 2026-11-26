import Foundation
import Accelerate
import AVFoundation
import QuartzCore

/// Real-time bass energy detector built on `vDSP` FFTs.
///
/// A 2048-point real FFT is run over each incoming tap buffer; energy in the
/// 30–150 Hz band is summed and converted to dB. A slow asymmetric average
/// tracks the local bass floor, so a hit is "energy well above the floor"
/// regardless of how loud the track is. All state is touched on one serial
/// queue (owned by the player), so no locking is required.
final class BassAnalyzer {

    /// 0 … 1, exposed to the settings slider.
    var sensitivity: Float = 0.6

    /// Normalised bass level 0 … 1 for UI animation.
    var onLevel: ((Float) -> Void)?

    /// Fired on a detected kick with a 0 … 1 strength.
    var onBeat: ((Float) -> Void)?

    private let fftSize: Int
    private let halfSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup

    private var window: [Float]
    private var windowed: [Float]
    private var realPart: [Float]
    private var imagPart: [Float]
    private var magnitudes: [Float]

    private var sampleRate: Double = 44_100
    private var bassBinCount: Int = 6
    private var noiseFloorDB: Float = -52
    private var smoothedLevel: Float = 0
    private var lastBeatTime: CFTimeInterval = 0
    private var lastAnalysisTime: CFTimeInterval = 0

    init(fftSize requestedSize: Int = 2048) {
        var size = max(512, requestedSize)
        // Round up to the nearest power of two.
        var power: Int = 1
        while power < size { power <<= 1 }
        size = power

        self.fftSize = size
        self.halfSize = size / 2
        self.log2n = vDSP_Length(log2(Double(size)).rounded())

        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("vDSP_create_fftsetup failed")
        }
        self.fftSetup = setup

        self.window = [Float](repeating: 0, count: size)
        self.windowed = [Float](repeating: 0, count: size)
        self.realPart = [Float](repeating: 0, count: size / 2)
        self.imagPart = [Float](repeating: 0, count: size / 2)
        self.magnitudes = [Float](repeating: 0, count: size / 2)

        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        updateBassBinCount()
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Forgets the adaptive floor — call when a new track starts.
    func reset() {
        noiseFloorDB = -52
        smoothedLevel = 0
        lastBeatTime = 0
        lastAnalysisTime = 0
    }

    /// Called on the analysis queue with a private copy of the tap buffer.
    func analyze(buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 64 else { return }

        let rate = buffer.format.sampleRate
        if abs(rate - sampleRate) > 1 {
            sampleRate = rate
            updateBassBinCount()
        }

        let size = fftSize
        let usable = min(frames, size)

        for index in 0..<size { windowed[index] = 0 }
        vDSP_vmul(channels[0], 1, window, 1, &windowed, 1, vDSP_Length(usable))

        realPart.withUnsafeMutableBufferPointer { realBuffer in
            imagPart.withUnsafeMutableBufferPointer { imagBuffer in
                magnitudes.withUnsafeMutableBufferPointer { magnitudeBuffer in
                    guard let realBase = realBuffer.baseAddress,
                          let imagBase = imagBuffer.baseAddress,
                          let magnitudeBase = magnitudeBuffer.baseAddress else { return }

                    var split = DSPSplitComplex(realp: realBase, imagp: imagBase)

                    windowed.withUnsafeBufferPointer { windowBuffer in
                        guard let base = windowBuffer.baseAddress else { return }
                        base.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexBuffer in
                            vDSP_ctoz(complexBuffer, 2, &split, 1, vDSP_Length(halfSize))
                        }
                    }

                    vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    vDSP_zvabs(&split, 1, magnitudeBase, 1, vDSP_Length(halfSize))

                    var scale = 1.0 / Float(size)
                    vDSP_vsmul(magnitudeBase, 1, &scale, magnitudeBase, 1, vDSP_Length(halfSize))
                }
            }
        }

        let bins = max(2, min(bassBinCount, halfSize - 1))
        var sum: Float = 0
        for index in 1...bins {
            sum += magnitudes[index]
        }

        let mean = sum / Float(bins)
        let decibels = 20 * log10f(max(mean, 1e-7))
        detect(levelDB: decibels)
    }

    // MARK: - Detection

    private func detect(levelDB: Float) {
        let now = CACurrentMediaTime()
        let delta = Float(max(0.001, min(0.25, now - lastAnalysisTime)))
        lastAnalysisTime = now

        // Asymmetric average: drops fast towards quiet passages, climbs slowly.
        if levelDB < noiseFloorDB {
            noiseFloorDB += (levelDB - noiseFloorDB) * min(0.9, 6.0 * delta)
        } else {
            noiseFloorDB += (levelDB - noiseFloorDB) * min(0.9, 0.30 * delta)
        }
        noiseFloorDB = min(max(noiseFloorDB, -85), -12)

        let over = levelDB - noiseFloorDB
        let clampedSensitivity = min(max(sensitivity, 0), 1)
        // 15 dB (rare hits) … 3 dB (every kick) above the local floor.
        let threshold: Float = 15 - 12 * clampedSensitivity

        let target = min(max((over - threshold + 3) / 16, 0), 1)
        if target > smoothedLevel {
            smoothedLevel += (target - smoothedLevel) * 0.55
        } else {
            smoothedLevel += (target - smoothedLevel) * 0.12
        }
        onLevel?(smoothedLevel)

        let refractory: CFTimeInterval = 0.10
        if over > threshold, levelDB > -60, now - lastBeatTime >= refractory {
            lastBeatTime = now
            let strength = min(max(0.35 + (over - threshold) / 22, 0), 1)
            onBeat?(strength)
        }
    }

    private func updateBassBinCount() {
        let binWidth = sampleRate / Double(fftSize)
        guard binWidth > 0 else { return }
        let limit = Int((150.0 / binWidth).rounded(.down))
        bassBinCount = max(2, min(halfSize - 1, limit))
    }
}
