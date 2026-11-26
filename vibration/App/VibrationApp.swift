import SwiftUI
import UIKit

@main
struct VibrationApp: App {

    init() {
        VibrationApp.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    /// Frosted, dark tab bar that matches the in-app glass cards.
    private static func configureAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tabAppearance.backgroundColor = UIColor(white: 0.02, alpha: 0.30)
        tabAppearance.shadowColor = UIColor(white: 1.0, alpha: 0.06)

        let itemAppearance = UITabBarItemAppearance()
        let idle = UIColor(white: 0.62, alpha: 1.0)
        let active = UIColor(red: 0.70, green: 0.56, blue: 1.00, alpha: 1.0)

        itemAppearance.normal.iconColor = idle
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: idle]
        itemAppearance.selected.iconColor = active
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: active]

        tabAppearance.stackedLayoutAppearance = itemAppearance
        tabAppearance.inlineLayoutAppearance = itemAppearance
        tabAppearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
