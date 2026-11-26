import SwiftUI

/// Central design tokens for the app: one violet→pink accent, one cyan→violet
/// secondary, soft glass surfaces and a fixed corner radius.
enum Theme {
    static let violet = Color(red: 0.56, green: 0.40, blue: 1.00)
    static let pink = Color(red: 0.98, green: 0.33, blue: 0.62)
    static let cyan = Color(red: 0.33, green: 0.84, blue: 0.99)

    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.56, green: 0.40, blue: 1.00),
            Color(red: 0.98, green: 0.33, blue: 0.62)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coolGradient = LinearGradient(
        colors: [
            Color(red: 0.33, green: 0.84, blue: 0.99),
            Color(red: 0.56, green: 0.40, blue: 1.00)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardStroke = LinearGradient(
        colors: [
            Color.white.opacity(0.22),
            Color.white.opacity(0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let radius: CGFloat = 24
}
