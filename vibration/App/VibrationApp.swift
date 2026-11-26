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
        tabAppearance.backgroundColor = UIColor(red: 0.098, green: 0.090, blue: 0.086, alpha: 0.42)
        tabAppearance.shadowColor = UIColor(red: 0.761, green: 0.659, blue: 0.471, alpha: 0.16)

        let itemAppearance = UITabBarItemAppearance()
        let idle = UIColor(red: 0.72, green: 0.67, blue: 0.59, alpha: 1.0)
        let active = UIColor(red: 0.761, green: 0.659, blue: 0.471, alpha: 1.0)

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
