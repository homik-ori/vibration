import Foundation

/// Static app metadata used by the UI (about card, repository link).
enum AppInfo {
    static let displayName = "vibration"
    static let version = "1.1.0"
    static let developer = "homik"
    static let buildNumber = "2"

    static let repositoryURL = URL(string: "https://github.com/homik-ori/vibration")!
    static let repositoryDisplay = "github.com/homik-ori/vibration"
    static let releasesURL = URL(string: "https://github.com/homik-ori/vibration/releases/latest")!

    /// Filled from the bundle when the app runs, fallback keeps previews happy.
    static var bundleVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? version
    }

    static var bundleBuild: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? buildNumber
    }
}
