import SwiftUI

/// Full-screen dark gradient with two ambient light blobs, used behind every tab.
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.07, blue: 0.15),
                    Color(red: 0.03, green: 0.02, blue: 0.05),
                    Color(red: 0.02, green: 0.02, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Theme.violet.opacity(0.34))
                .frame(width: 430, height: 430)
                .blur(radius: 130)
                .offset(x: -150, y: -300)

            Circle()
                .fill(Theme.pink.opacity(0.20))
                .frame(width: 360, height: 360)
                .blur(radius: 130)
                .offset(x: 170, y: 330)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Frosted, rounded card with a hairline gradient border.
struct GlassCard<Content: View>: View {
    var padding: CGFloat
    var content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Theme.cardStroke, lineWidth: 0.9)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}

/// Scales + brightens while pressed; used on every tappable surface.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

/// Small uppercase caption used above sections.
struct SectionCaption: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.4)
            .foregroundColor(.white.opacity(0.40))
    }
}

/// Compact info row used in the "about" card.
struct InfoRow: View {
    let title: String
    let value: String
    var valueColor: Color = .white.opacity(0.85)

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.50))
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundColor(valueColor)
        }
    }
}

/// Row with a round status dot + label, used for hardware capability checks.
struct CapabilityRow: View {
    let title: String
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isAvailable ? Color.green.opacity(0.85) : Color.white.opacity(0.18))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.80))
            Spacer()
            Text(isAvailable ? "есть" : "нет")
                .font(.caption2.weight(.semibold))
                .foregroundColor(isAvailable ? Color.green.opacity(0.85) : .white.opacity(0.35))
        }
    }
}
