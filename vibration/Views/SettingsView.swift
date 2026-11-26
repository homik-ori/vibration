import SwiftUI
import ARKit

/// Tab 3 — haptic tuning, engine test and the about card.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                slidersSection
                testButton
                aboutCard
                capabilitiesCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 110)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Настройки")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("характер вибрации")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.45))
        }
    }

    // MARK: - Sliders

    private var slidersSection: some View {
        VStack(spacing: 12) {
            SettingSliderCard(
                title: "Сила вибрации",
                caption: "Амплитуда удара",
                systemImage: "waveform",
                valueText: settings.strengthPercentText,
                value: $settings.strength,
                range: 0.1...1.0
            )

            SettingSliderCard(
                title: "Резкость отклика",
                caption: "От мягкого баса до щелчка",
                systemImage: "bolt.fill",
                valueText: settings.sharpnessPercentText,
                value: $settings.sharpness,
                range: 0...1
            )

            SettingSliderCard(
                title: "Чувствительность к басу",
                caption: "Ниже порог — больше срабатываний",
                systemImage: "dial.medium.fill",
                valueText: settings.sensitivityPercentText,
                value: $settings.bassSensitivity,
                range: 0...1
            )

            GlassCard(padding: 16) {
                Toggle(isOn: $settings.hapticsEnabled) {
                    HStack(spacing: 11) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.08)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Вибрация в плеере")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.92))
                            Text("Отклик на каждый удар баса")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }
                }
                .tint(Theme.violet)
            }
        }
    }

    // MARK: - Test

    private var testButton: some View {
        Button {
            HapticsManager.shared.test(strength: settings.strength, sharpness: settings.sharpness)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16, weight: .semibold))
                Text("Протестировать Taptic Engine")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.accentGradient)
            )
            .shadow(color: Theme.violet.opacity(0.45), radius: 18, y: 8)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.97))
    }

    // MARK: - About

    private var aboutCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.accentGradient)
                            .frame(width: 52, height: 52)

                        Image(systemName: "waveform")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Theme.violet.opacity(0.45), radius: 14, y: 5)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("vibration")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Версия \(appVersion)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.45))
                    }

                    Spacer()
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.8)

                HStack(alignment: .firstTextBaseline) {
                    Text("Разработчик")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    Text("by homik")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accentGradient)
                }

                Text("Нативное iOS-приложение: FFT-анализ баса через Accelerate, тактильная отдача Core Haptics, 3D-сканер глубины на ARKit и тактильный парктроник.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.40))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Hardware

    private var capabilitiesCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.cyan)
                    Text("Оборудование")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))
                }

                CapabilityRow(title: "Taptic Engine", isAvailable: HapticsManager.shared.supportsHaptics)
                CapabilityRow(
                    title: "Задний LiDAR",
                    isAvailable: ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
                )
                CapabilityRow(title: "Фронтальный TrueDepth", isAvailable: ARFaceTrackingConfiguration.isSupported)
            }
        }
    }
}

// MARK: - Slider card

struct SettingSliderCard: View {
    let title: String
    let caption: String
    let systemImage: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 11) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.08)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.92))
                        Text(caption)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.45))
                    }

                    Spacer()

                    Text(valueText)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }

                Slider(value: $value, in: range)
                    .tint(Theme.violet)
            }
        }
    }
}
