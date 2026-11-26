import SwiftUI
import UIKit

/// Tab «Тап» — a large pad that covers most of the screen. Every touch fires a
/// crisp click through the Taptic Engine and paints a gold ripple under the finger.
struct TapPadView: View {
    @ObservedObject private var settings = AppSettings.shared

    @State private var ripples: [TapRipple] = []
    @State private var tapCount: Int = 0
    @State private var glow: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 10)

            padArea
                .padding(.horizontal, 14)

            footer
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 10)
        }
        .onAppear {
            HapticsManager.shared.prepare()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Тап")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("щелчок на каждое касание")
                    .font(.footnote)
                    .foregroundColor(Theme.gold.opacity(0.75))
            }
            Spacer()
        }
    }

    // MARK: - Pad

    private var padArea: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.inkRaised, Theme.ink],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [Theme.wine.opacity(0.55), Theme.wine.opacity(0.0)],
                            center: .center,
                            startRadius: 10,
                            endRadius: max(geometry.size.width, geometry.size.height) * 0.72
                        )
                    )

                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Theme.gold.opacity(0.13 - Double(index) * 0.03), lineWidth: 1)
                        .frame(
                            width: CGFloat(180 + index * 110),
                            height: CGFloat(180 + index * 110)
                        )
                        .allowsHitTesting(false)
                }

                VStack(spacing: 10) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(Theme.goldGradient)
                        .shadow(color: Theme.gold.opacity(0.35), radius: 18)

                    Text("Тапайте по этой области")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.88))

                    Text("Каждый тап — щелчок Taptic Engine")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.45))
                }
                .allowsHitTesting(false)

                // Touch surface: a plain UIView gives instant, multi-touch aware
                // `touchesBegan`, which feels snappier than a SwiftUI gesture.
                TapCatchView { point in
                    registerTap(at: point)
                }

                ForEach(ripples) { ripple in
                    TapRippleView(location: ripple.location)
                }

                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(glow ? 0.55 : 0.22), lineWidth: 1.2)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .animation(.easeOut(duration: 0.18), value: glow)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.gold)

                Text("Нажатий")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.45))

                Text("\(tapCount)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }

            Spacer()

            Text("Сила \(settings.strengthPercentText)")
                .font(.caption2.weight(.semibold))
                .foregroundColor(Theme.gold.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.16), lineWidth: 0.8)
        )
    }

    // MARK: - Tap handling

    private func registerTap(at point: CGPoint) {
        tapCount += 1
        HapticsManager.shared.click(intensity: settings.strength)

        glow = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            glow = false
        }

        let ripple = TapRipple(location: point)
        ripples.append(ripple)
        if ripples.count > 12 {
            ripples.removeFirst(ripples.count - 12)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

// MARK: - Touch surface

private struct TapCatchView: UIViewRepresentable {
    var onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> TapCatchUIView {
        let view = TapCatchUIView()
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: TapCatchUIView, context: Context) {
        uiView.onTap = onTap
    }
}

final class TapCatchUIView: UIView {
    var onTap: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        for touch in touches {
            onTap?(touch.location(in: self))
        }
    }
}

// MARK: - Ripple

private struct TapRipple: Identifiable {
    let id = UUID()
    let location: CGPoint
}

private struct TapRippleView: View {
    let location: CGPoint
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.gold.opacity(0.9), lineWidth: 2)
                .frame(width: 46, height: 46)
                .scaleEffect(1 + progress * 2.4)
                .opacity(Double(1 - progress))

            Circle()
                .fill(Theme.gold.opacity(0.30))
                .frame(width: 24, height: 24)
                .scaleEffect(1 + progress * 1.2)
                .opacity(Double(1 - progress))
        }
        .position(location)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                progress = 1
            }
        }
    }
}
