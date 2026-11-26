import SwiftUI
import UIKit
import Foundation

/// Artwork stand-in: a dark tile with two ambient gradient blobs that breathe
/// with the bass, a ring that bursts on every detected kick, and a live
/// spectrum of low-frequency bars.
struct PulsingArtwork: View {
    var level: Float
    var beatCount: Int
    var isPlaying: Bool
    var title: String

    @State private var burst: CGFloat = 0

    private var normalizedLevel: CGFloat {
        CGFloat(max(0, min(1, level)))
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            ZStack {
                RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                    .fill(Color.white.opacity(0.04))

                RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.07, blue: 0.22),
                                Color(red: 0.20, green: 0.09, blue: 0.30),
                                Color(red: 0.06, green: 0.05, blue: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Ambient blobs driven by the low-frequency envelope.
                Circle()
                    .fill(Theme.violet.opacity(0.55))
                    .frame(width: side * 0.72, height: side * 0.72)
                    .blur(radius: side * 0.11)
                    .offset(
                        x: -side * 0.10 + normalizedLevel * side * 0.06,
                        y: -side * 0.14 - normalizedLevel * side * 0.08
                    )
                    .scaleEffect(1 + normalizedLevel * 0.22)

                Circle()
                    .fill(Theme.pink.opacity(0.42))
                    .frame(width: side * 0.62, height: side * 0.62)
                    .blur(radius: side * 0.12)
                    .offset(
                        x: side * 0.16 - normalizedLevel * side * 0.05,
                        y: side * 0.18 + normalizedLevel * side * 0.07
                    )
                    .scaleEffect(1 + normalizedLevel * 0.26)

                // Beat ring burst.
                Circle()
                    .stroke(Theme.accentGradient, lineWidth: max(1.5, side * 0.006))
                    .frame(width: side * 0.46, height: side * 0.46)
                    .scaleEffect(1 + burst * 0.55)
                    .opacity(Double(1 - burst) * 0.85)

                VStack(spacing: side * 0.055) {
                    Image(systemName: isPlaying ? "waveform" : "waveform.slash")
                        .font(.system(size: side * 0.19, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white.opacity(0.95), .white.opacity(0.62)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(1 + normalizedLevel * 0.10)
                        .shadow(color: Theme.violet.opacity(0.55), radius: 18)

                    Text(title.isEmpty ? "vibration" : title)
                        .font(.system(size: side * 0.048, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .padding(.horizontal, side * 0.08)
                }

                VStack {
                    Spacer()
                    BassBars(level: normalizedLevel, barCount: 26)
                        .frame(height: side * 0.10)
                        .padding(.horizontal, side * 0.10)
                        .padding(.bottom, side * 0.07)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: side * 0.10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Theme.violet.opacity(0.35), radius: 30, x: 0, y: 18)
            .animation(.easeOut(duration: 0.16), value: normalizedLevel)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: beatCount) { _ in
            burst = 0
            withAnimation(.easeOut(duration: 0.55)) {
                burst = 1
            }
        }
    }
}

/// Deterministic low-frequency "spectrum" that reacts to the analyser envelope.
struct BassBars: View {
    var level: CGFloat
    var barCount: Int

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 3
            let barWidth = max(2, (geometry.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount))
            let maxHeight = geometry.size.height

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.cyan.opacity(0.9), Theme.violet.opacity(0.9)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: barWidth, height: height(for: index, maxHeight: maxHeight))
                }
            }
            .frame(width: geometry.size.width, height: maxHeight, alignment: .bottom)
        }
    }

    private func height(for index: Int, maxHeight: CGFloat) -> CGFloat {
        let position = Double(index) / Double(max(1, barCount - 1))
        let shape = 0.35 + 0.65 * abs(sin(position * .pi * 2.4 + 0.6))
        let envelope = 0.16 + 0.84 * Double(level)
        let value = shape * envelope * (1 - 0.35 * abs(position - 0.5))
        return max(2, CGFloat(value) * maxHeight)
    }
}
