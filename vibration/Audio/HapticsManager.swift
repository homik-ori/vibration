import Foundation
import CoreHaptics
import UIKit
import QuartzCore

/// Serialised wrapper around `CHHapticEngine`.
///
/// The engine lives on its own queue because Core Haptics requires all player
/// calls to be serialised. Every bass hit reuses a single pre-built transient
/// player and only pushes dynamic intensity/sharpness parameters into it, so a
/// beat costs no allocations. A hard cooldown keeps the Taptic Engine from
/// "choking" on dense basslines.
final class HapticsManager {
    static let shared = HapticsManager()

    let supportsHaptics: Bool

    private let engineQueue = DispatchQueue(label: "com.homik.vibration.haptics", qos: .userInteractive)
    private var engine: CHHapticEngine?
    private var transientPlayer: CHHapticPatternPlayer?
    private var testPlayer: CHHapticPatternPlayer?
    private var engineReady = false

    private var lastPulseTime: CFTimeInterval = 0
    private let cooldown: CFTimeInterval = 0.08

    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        mediumImpact.prepare()
        lightImpact.prepare()
        softImpact.prepare()
    }

    // MARK: - Lifecycle

    /// Warms the engine up so the first bass hit is not lost.
    func prepare() {
        guard supportsHaptics else { return }
        engineQueue.async { [weak self] in
            self?.startEngineLocked()
        }
    }

    /// Releases the engine; called when leaving the music tab.
    func stop() {
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            self.engineReady = false
            self.transientPlayer = nil
            self.testPlayer = nil
            self.engine?.stop(completionHandler: nil)
        }
    }

    // MARK: - Bass hits

    func pulse(intensity: Double, sharpness: Double) {
        let level = max(0.0, min(1.0, intensity))
        let crisp = max(0.0, min(1.0, sharpness))

        guard supportsHaptics else {
            DispatchQueue.main.async {
                self.mediumImpact.impactOccurred(intensity: CGFloat(max(0.15, level)))
                self.mediumImpact.prepare()
            }
            return
        }

        engineQueue.async { [weak self] in
            guard let self = self else { return }
            let now = CACurrentMediaTime()
            guard now - self.lastPulseTime >= self.cooldown else { return }
            self.lastPulseTime = now

            guard self.engineReady, let player = self.transientPlayer else {
                self.startEngineLocked()
                return
            }

            do {
                let parameters = [
                    CHHapticDynamicParameter(
                        parameterID: .hapticIntensityControl,
                        value: Float(level),
                        relativeTime: 0
                    ),
                    CHHapticDynamicParameter(
                        parameterID: .hapticSharpnessControl,
                        value: Float(crisp),
                        relativeTime: 0
                    )
                ]
                try player.sendParameters(parameters, atTime: 0)
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                self.engineReady = false
                self.transientPlayer = nil
                self.startEngineLocked()
            }
        }
    }

    // MARK: - Settings test pattern

    func test(strength: Double, sharpness: Double) {
        let level = Float(max(0.1, min(1.0, strength)))
        let crisp = Float(max(0.0, min(1.0, sharpness)))

        guard supportsHaptics else {
            DispatchQueue.main.async {
                self.mediumImpact.impactOccurred(intensity: CGFloat(level))
                self.mediumImpact.prepare()
            }
            return
        }

        engineQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.engineReady {
                self.startEngineLocked()
            }
            guard let engine = self.engine, self.engineReady else { return }

            do {
                var events: [CHHapticEvent] = []
                for index in 0..<3 {
                    events.append(
                        CHHapticEvent(
                            eventType: .hapticTransient,
                            parameters: [
                                CHHapticEventParameter(parameterID: .hapticIntensity, value: level),
                                CHHapticEventParameter(parameterID: .hapticSharpness, value: crisp)
                            ],
                            relativeTime: Double(index) * 0.14
                        )
                    )
                }
                events.append(
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: level * 0.8),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: crisp)
                        ],
                        relativeTime: 0.52,
                        duration: 0.34
                    )
                )

                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine.makePlayer(with: pattern)
                self.testPlayer = player
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                self.engineReady = false
            }
        }
    }

    // MARK: - UI feedback

    /// Single light tick for the proximity "parktronic".
    func tick(intensity: CGFloat) {
        DispatchQueue.main.async {
            self.lightImpact.impactOccurred(intensity: max(0.2, min(1.0, intensity)))
            self.lightImpact.prepare()
        }
    }

    /// Subtle tap for buttons.
    func uiTap() {
        DispatchQueue.main.async {
            self.softImpact.impactOccurred(intensity: 0.7)
            self.softImpact.prepare()
        }
    }

    // MARK: - Private

    private func startEngineLocked() {
        do {
            let engine: CHHapticEngine
            if let existing = self.engine {
                engine = existing
            } else {
                engine = try CHHapticEngine()
                engine.playsHapticsOnly = true
                engine.isAutoShutdownEnabled = true
                engine.stoppedHandler = { [weak self] _ in
                    self?.engineQueue.async {
                        self?.engineReady = false
                        self?.transientPlayer = nil
                    }
                }
                engine.resetHandler = { [weak self] in
                    guard let self = self else { return }
                    self.engineQueue.async {
                        self.engineReady = false
                        self.transientPlayer = nil
                        self.startEngineLocked()
                    }
                }
                self.engine = engine
            }

            try engine.start()
            engineReady = true
            buildTransientPlayerLocked(in: engine)
        } catch {
            engineReady = false
        }
    }

    private func buildTransientPlayerLocked(in engine: CHHapticEngine) {
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            transientPlayer = try engine.makePlayer(with: pattern)
        } catch {
            transientPlayer = nil
        }
    }
}
