import SwiftUI
import UIKit
import ARKit

/// Tab 2 — universal depth scanner: rear LiDAR on 12 Pro and newer, front
/// TrueDepth on XS Max / 11 / 12 / 13 / 14 / 15 / 16 and later non-Pro phones.
struct LidarScannerView: View {
    @ObservedObject var scanner: DepthScannerController
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header

                if scanner.availableModes.isEmpty {
                    unsupportedCard
                } else {
                    if scanner.availableModes.count > 1 {
                        modeSelector
                    }
                    previewCard
                    proximityCard
                    sensorCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 110)
        }
        .onAppear {
            scanner.activate()
        }
        .onDisappear {
            scanner.deactivate()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Лидар")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("3D-сканер глубины")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.45))
        }
    }

    // MARK: - Mode selector

    private var modeSelector: some View {
        HStack(spacing: 6) {
            ForEach(scanner.availableModes) { mode in
                Button {
                    HapticsManager.shared.uiTap()
                    scanner.select(mode)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode == .rear ? "cube.transparent" : "faceid")
                            .font(.system(size: 12, weight: .semibold))
                        Text(mode.title)
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundColor(scanner.mode == mode ? .white : .white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(scanner.mode == mode ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                    )
                }
                .buttonStyle(PressableButtonStyle(scale: 0.97))
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Camera preview

    private var previewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black)

            ARScannerView(controller: scanner)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            ScannerReticle(mode: scanner.mode, tracking: scanner.trackingNormal)
                .allowsHitTesting(false)

            VStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(scanner.distance == nil ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)
                    Text(scanner.mode.sensorName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                    Text(scanner.isRunning ? "активен" : "пауза")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                .padding(.top, 14)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(scanner.distanceText)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                    Text(scanner.distanceDetail)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8))
                .padding(.bottom, 16)
            }

            if scanner.cameraDenied {
                permissionOverlay
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var permissionOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)

            VStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.7))

                Text("Нет доступа к камере")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Разрешите камеру в настройках, чтобы измерять глубину.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Button {
                    openSettings()
                } label: {
                    Text("Открыть настройки")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.accentGradient))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Proximity haptics

    private var proximityCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $settings.proximityHaptics) {
                    HStack(spacing: 11) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.08)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Тактильный парктроник")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.92))
                            Text("Чем ближе объект, тем чаще тики")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }
                }
                .tint(Theme.violet)
                .onChange(of: settings.proximityHaptics) { newValue in
                    if newValue { HapticsManager.shared.tick(intensity: 0.5) }
                }

                if settings.proximityHaptics {
                    Text(scanner.proximityRateText)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.40))
                        .padding(.leading, 43)
                }
            }
        }
    }

    // MARK: - Sensor details

    private var sensorCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.cyan)
                    Text("Датчики устройства")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))
                }

                InfoRow(title: "Найдено", value: scanner.sensorsDescription)
                InfoRow(title: "Режим", value: scanner.mode.title)
                InfoRow(title: "Дальность", value: scanner.mode.rangeText)
                InfoRow(title: "Точность", value: "±1 см")

                Text(scanner.mode.hint)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Unsupported

    private var unsupportedCard: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Датчики глубины не найдены")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }
                Text("Этому устройству нужен TrueDepth или LiDAR. На iPhone XS Max и новее фронтальный сканер работает всегда.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.50))
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

// MARK: - Reticle overlay

/// Crosshair (rear LiDAR) or face oval (front TrueDepth) plus frame brackets.
struct ScannerReticle: View {
    let mode: ScannerMode
    let tracking: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let bracketInset: CGFloat = 16
            let bracketLength: CGFloat = 26

            ZStack {
                CornerBracket()
                    .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: bracketLength, height: bracketLength)
                    .position(x: bracketInset + bracketLength / 2, y: bracketInset + bracketLength / 2)

                CornerBracket()
                    .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: bracketLength, height: bracketLength)
                    .rotationEffect(.degrees(90))
                    .position(x: geometry.size.width - bracketInset - bracketLength / 2, y: bracketInset + bracketLength / 2)

                CornerBracket()
                    .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: bracketLength, height: bracketLength)
                    .rotationEffect(.degrees(-90))
                    .position(x: bracketInset + bracketLength / 2, y: geometry.size.height - bracketInset - bracketLength / 2)

                CornerBracket()
                    .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: bracketLength, height: bracketLength)
                    .rotationEffect(.degrees(180))
                    .position(x: geometry.size.width - bracketInset - bracketLength / 2, y: geometry.size.height - bracketInset - bracketLength / 2)

                if mode == .rear {
                    Crosshair()
                        .stroke(Color.white.opacity(tracking ? 0.85 : 0.45), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        .frame(width: size * 0.16, height: size * 0.16)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                } else {
                    Ellipse()
                        .strokeBorder(
                            Theme.coolGradient,
                            style: StrokeStyle(lineWidth: 2, dash: [9, 7])
                        )
                        .frame(width: size * 0.34, height: size * 0.42)
                        .opacity(tracking ? 0.9 : 0.45)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.46)
                }
            }
        }
    }
}

struct Crosshair: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )

        path.move(to: CGPoint(x: center.x - radius * 1.7, y: center.y))
        path.addLine(to: CGPoint(x: center.x - radius * 0.55, y: center.y))
        path.move(to: CGPoint(x: center.x + radius * 0.55, y: center.y))
        path.addLine(to: CGPoint(x: center.x + radius * 1.7, y: center.y))

        path.move(to: CGPoint(x: center.x, y: center.y - radius * 1.7))
        path.addLine(to: CGPoint(x: center.x, y: center.y - radius * 0.55))
        path.move(to: CGPoint(x: center.x, y: center.y + radius * 0.55))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius * 1.7))

        return path
    }
}

struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
