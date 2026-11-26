import Foundation
import AVFoundation
import Combine

/// One imported audio file.
struct Track: Identifiable, Hashable {
    let id: String
    let url: URL
    let title: String
    let duration: Double

    var durationText: String {
        MusicPlayerEngine.timeString(duration)
    }
}

/// File playback (AVAudioPlayerNode) + tap-based FFT analysis + haptic beats.
///
/// The engine is only running while the Music tab is visible and playback is
/// active: `suspend()` tears down the tap and stops the engine, which keeps the
/// CPU cool and the battery untouched while the user is on another tab.
final class MusicPlayerEngine: ObservableObject {

    // MARK: - Published state

    @Published private(set) var tracks: [Track] = []
    @Published private(set) var currentTrack: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published private(set) var bassLevel: Float = 0
    @Published private(set) var beatCount: Int = 0
    @Published private(set) var isEngineRunning = false
    @Published var position: Double = 0
    @Published var lastError: String?

    // MARK: - Audio graph

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let analyzer = BassAnalyzer(fftSize: 2048)
    private let analysisQueue = DispatchQueue(label: "com.homik.vibration.fft", qos: .userInitiated)

    private var audioFile: AVAudioFile?
    private var tapInstalled = false
    private var graphConfigured = false

    // MARK: - Timeline

    private var ticker: Timer?
    private var playStartedAt: Date?
    private var positionAtStart: Double = 0
    private var generation: Int = 0

    init() {
        engine.attach(playerNode)

        analyzer.sensitivity = Float(AppSettings.shared.bassSensitivity)

        analyzer.onLevel = { [weak self] level in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.bassLevel = self.isPlaying ? level : 0
            }
        }

        analyzer.onBeat = { [weak self] strength in
            DispatchQueue.main.async {
                guard let self = self, self.isPlaying else { return }
                self.beatCount &+= 1
                self.bassLevel = max(self.bassLevel, min(1, strength))

                let settings = AppSettings.shared
                guard settings.hapticsEnabled else { return }
                let intensity = settings.strength * (0.45 + 0.55 * Double(strength))
                HapticsManager.shared.pulse(intensity: intensity, sharpness: settings.sharpness)
            }
        }
    }

    deinit {
        ticker?.invalidate()
        if tapInstalled {
            engine.mainMixerNode.removeTap(onBus: 0)
        }
        engine.stop()
    }

    // MARK: - Library

    func reloadLibrary() {
        let loaded = AudioLibrary.tracks()
        tracks = loaded

        if let current = currentTrack {
            if let refreshed = loaded.first(where: { $0.id == current.id }) {
                currentTrack = refreshed
                if !isPlaying && position == 0 {
                    duration = refreshed.duration
                }
            } else {
                currentTrack = nil
                audioFile = nil
                duration = 0
                position = 0
            }
        }

        if currentTrack == nil, let first = loaded.first {
            currentTrack = first
            duration = first.duration
        }
    }

    func importTracks(_ urls: [URL]) {
        var failure: String?
        for url in urls {
            do {
                _ = try AudioLibrary.importFile(from: url)
            } catch {
                failure = "Не удалось импортировать «\(url.lastPathComponent)»."
            }
        }
        if let failure = failure {
            lastError = failure
        }
        reloadLibrary()
    }

    func delete(_ track: Track) {
        if currentTrack?.id == track.id {
            pause()
            audioFile = nil
            currentTrack = nil
            duration = 0
            position = 0
        }
        AudioLibrary.delete(track)
        reloadLibrary()
    }

    func isCurrent(_ track: Track) -> Bool {
        currentTrack?.id == track.id
    }

    // MARK: - Transport

    func togglePlayPause() {
        if isPlaying {
            pause()
            return
        }

        if audioFile != nil, currentTrack != nil {
            let resumePoint = position >= max(0, duration - 0.25) ? 0 : position
            startPlayback(from: resumePoint)
        } else if let track = currentTrack {
            play(track)
        } else if let first = tracks.first {
            play(first)
        }
    }

    func play(_ track: Track) {
        do {
            let file = try AVAudioFile(forReading: track.url)
            audioFile = file
            currentTrack = track
            duration = Double(file.length) / file.processingFormat.sampleRate
            configureGraph(for: file)
            startPlayback(from: 0)
        } catch {
            audioFile = nil
            lastError = "Не удалось открыть «\(track.title)». Формат не поддерживается."
        }
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        playStartedAt = nil
        stopTicker()
        generation += 1
        playerNode.stop()
        bassLevel = 0
    }

    func seek(to time: Double) {
        guard audioFile != nil else { return }
        let target = max(0, min(time, max(0, duration - 0.05)))
        position = target

        if isPlaying {
            startPlayback(from: target)
        } else {
            positionAtStart = target
            generation += 1
            playerNode.stop()
            if let file = audioFile {
                scheduleSegment(file: file, from: target, generation: generation)
            }
        }
    }

    func skip(by seconds: Double) {
        seek(to: position + seconds)
    }

    /// Stops playback and releases the audio engine — called when the tab changes.
    func suspend() {
        if isPlaying { pause() }
        stopTicker()

        if tapInstalled {
            engine.mainMixerNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning {
            engine.stop()
        }
        isEngineRunning = false
        bassLevel = 0

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Ignore: the session may already be inactive.
        }
    }

    /// Restores the analyser sensitivity after the settings slider moved.
    func applySettings() {
        analyzer.sensitivity = Float(AppSettings.shared.bassSensitivity)
    }

    // MARK: - Private — graph

    private func configureGraph(for file: AVAudioFile) {
        if engine.isRunning {
            engine.stop()
        }
        isEngineRunning = false

        playerNode.stop()
        engine.disconnectNodeOutput(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
        engine.prepare()
        graphConfigured = true
    }

    private func installTapIfNeeded() {
        guard !tapInstalled else { return }
        let mixer = engine.mainMixerNode
        mixer.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
            guard let self = self else { return }
            // The tap buffer is recycled as soon as this block returns.
            guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return }
            copy.frameLength = buffer.frameLength
            if let source = buffer.floatChannelData, let destination = copy.floatChannelData {
                let channelCount = Int(buffer.format.channelCount)
                let byteCount = Int(buffer.frameLength) * MemoryLayout<Float>.size
                for channel in 0..<channelCount {
                    memcpy(destination[channel], source[channel], byteCount)
                }
            }
            self.analysisQueue.async {
                self.analyzer.analyze(buffer: copy)
            }
        }
        tapInstalled = true
    }

    private func startEngineIfNeeded() {
        if engine.isRunning {
            isEngineRunning = true
            return
        }

        installTapIfNeeded()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            // Playback can still work with the default category.
        }

        do {
            engine.prepare()
            try engine.start()
            isEngineRunning = true
        } catch {
            isEngineRunning = false
            lastError = "Не удалось запустить аудиодвижок."
        }
    }

    private func startPlayback(from time: Double) {
        guard let file = audioFile, graphConfigured else { return }

        analyzer.reset()
        generation += 1
        let activeGeneration = generation

        positionAtStart = time
        position = time

        playerNode.stop()
        scheduleSegment(file: file, from: time, generation: activeGeneration)
        startEngineIfNeeded()

        guard isEngineRunning else { return }

        playerNode.play()
        isPlaying = true
        playStartedAt = Date()
        startTicker()

        HapticsManager.shared.prepare()
    }

    private func scheduleSegment(file: AVAudioFile, from time: Double, generation activeGeneration: Int) {
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(max(0, time) * sampleRate)
        guard startFrame < file.length else { return }

        let remainingFrames = file.length - startFrame
        guard remainingFrames > 0 else { return }
        let frameCount = AVAudioFrameCount(remainingFrames)

        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil
        ) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.generation == activeGeneration else { return }
                self.finishPlayback()
            }
        }
    }

    private func finishPlayback() {
        isPlaying = false
        playStartedAt = nil
        stopTicker()
        position = duration
        bassLevel = 0
    }

    // MARK: - Private — timeline

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tickPosition()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tickPosition() {
        guard isPlaying, let started = playStartedAt else { return }
        let value = positionAtStart + Date().timeIntervalSince(started)

        if duration > 0, value >= duration {
            finishPlayback()
        } else {
            position = max(0, value)
        }
    }

    // MARK: - Formatting

    static func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
