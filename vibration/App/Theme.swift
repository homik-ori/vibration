import SwiftUI

/// Palette lifted from the reference art card:
/// wine `#773344`, aged gold `#C2A878`, near-black `#191716`.
enum Theme {
    // MARK: Wine — #773344 family
    static let wine = Color(red: 0.467, green: 0.200, blue: 0.267)
    static let wineDeep = Color(red: 0.278, green: 0.110, blue: 0.153)
    static let wineSoft = Color(red: 0.376, green: 0.160, blue: 0.212)

    // MARK: Aged gold — #C2A878 family
    static let gold = Color(red: 0.761, green: 0.659, blue: 0.471)
    static let goldDeep = Color(red: 0.596, green: 0.506, blue: 0.341)
    static let goldLight = Color(red: 0.898, green: 0.831, blue: 0.686)

    // MARK: Ink — #191716 family
    static let ink = Color(red: 0.098, green: 0.090, blue: 0.086)
    static let inkRaised = Color(red: 0.145, green: 0.129, blue: 0.122)

    /// Burgundy fills for cards, buttons and artwork.
    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.467, green: 0.200, blue: 0.267),
            Color(red: 0.278, green: 0.110, blue: 0.153)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Metallic gold for primary CTAs and accents.
    static let goldGradient = LinearGradient(
        colors: [
            Color(red: 0.898, green: 0.831, blue: 0.686),
            Color(red: 0.761, green: 0.659, blue: 0.471),
            Color(red: 0.596, green: 0.506, blue: 0.341)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Gold → wine sweep used by the scanner reticle.
    static let reticleGradient = LinearGradient(
        colors: [
            Color(red: 0.761, green: 0.659, blue: 0.471),
            Color(red: 0.467, green: 0.200, blue: 0.267)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardStroke = LinearGradient(
        colors: [
            Color(red: 0.761, green: 0.659, blue: 0.471).opacity(0.30),
            Color(red: 0.761, green: 0.659, blue: 0.471).opacity(0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let radius: CGFloat = 24
}
