import Foundation
import Combine

/// User-tunable values, persisted in UserDefaults and shared app-wide.
/// Views observe it directly, the audio/haptic engines read `shared`.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    /// 0.10 … 1.00 — scales the transient haptic intensity.
    @Published var strength: Double {
        didSet { defaults.set(strength, forKey: Keys.strength) }
    }

    /// 0.00 … 1.00 — 0 is a dull bass thump, 1 is a sharp click.
    @Published var sharpness: Double {
        didSet { defaults.set(sharpness, forKey: Keys.sharpness) }
    }

    /// 0.00 … 1.00 — how easily the FFT bass detector fires.
    @Published var bassSensitivity: Double {
        didSet { defaults.set(bassSensitivity, forKey: Keys.sensitivity) }
    }

    /// Master switch for bass-driven haptics.
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.enabled) }
    }

    /// "Тактильный парктроник" for the depth scanner.
    @Published var proximityHaptics: Bool {
        didSet { defaults.set(proximityHaptics, forKey: Keys.proximity) }
    }

    private enum Keys {
        static let strength = "vibration.haptic.strength"
        static let sharpness = "vibration.haptic.sharpness"
        static let sensitivity = "vibration.bass.sensitivity"
        static let enabled = "vibration.haptic.enabled"
        static let proximity = "vibration.scanner.proximity"
    }

    private let defaults = UserDefaults.standard

    private init() {
        let store = UserDefaults.standard
        strength = (store.object(forKey: Keys.strength) as? Double) ?? 0.75
        sharpness = (store.object(forKey: Keys.sharpness) as? Double) ?? 0.45
        bassSensitivity = (store.object(forKey: Keys.sensitivity) as? Double) ?? 0.60
        hapticsEnabled = (store.object(forKey: Keys.enabled) as? Bool) ?? true
        proximityHaptics = (store.object(forKey: Keys.proximity) as? Bool) ?? true
    }

    var strengthPercentText: String {
        "\(Int((strength * 100).rounded()))%"
    }

    var sharpnessPercentText: String {
        "\(Int((sharpness * 100).rounded()))%"
    }

    var sensitivityPercentText: String {
        "\(Int((bassSensitivity * 100).rounded()))%"
    }
}
