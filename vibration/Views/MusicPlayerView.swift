import SwiftUI
import UniformTypeIdentifiers

/// Tab 1 — Apple Music inspired player with a bass-reactive artwork and the
/// FFT → Core Haptics engine behind it.
struct MusicPlayerView: View {
    @ObservedObject var player: MusicPlayerEngine
    @ObservedObject private var settings = AppSettings.shared

    @State private var showImporter = false
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    private var importTypes: [UTType] {
        var types: [UTType] = [.audio, .mp3, .wav, .mpeg4Audio]
        if let flac = UTType(filenameExtension: "flac") { types.append(flac) }
        if let aiff = UTType(filenameExtension: "aiff") { types.append(aiff) }
        return types
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { isScrubbing ? scrubValue : player.position },
            set: { scrubValue = $0 }
        )
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 22) {
                header
                artwork
                trackInfo
                timeline
                transport
                libraryCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 110)
        }
        .onAppear {
            player.reloadLibrary()
            player.applySettings()
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: importTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                player.importTracks(urls)
            case .failure(let error):
                player.lastError = error.localizedDescription
            }
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { player.lastError != nil },
                set: { newValue in if !newValue { player.lastError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { player.lastError = nil }
        } message: {
            Text(player.lastError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("vibration")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("вибрация в такт басам")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()

            Button {
                HapticsManager.shared.uiTap()
                settings.hapticsEnabled.toggle()
            } label: {
                Image(systemName: settings.hapticsEnabled ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(settings.hapticsEnabled ? .white : .white.opacity(0.35))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8))
            }
            .buttonStyle(PressableButtonStyle())

            Button {
                HapticsManager.shared.uiTap()
                showImporter = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.accentGradient))
                    .overlay(Circle().strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
                    .shadow(color: Theme.gold.opacity(0.28), radius: 12, y: 5)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Artwork

    private var artwork: some View {
        PulsingArtwork(
            level: player.bassLevel,
            beatCount: player.beatCount,
            isPlaying: player.isPlaying,
            title: player.currentTrack?.title ?? ""
        )
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Track info

    private var trackInfo: some View {
        VStack(spacing: 6) {
            Text(player.currentTrack?.title ?? "Нет трека")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(player.currentTrack == nil ? "Импортируйте музыку из «Файлов»" : settings.hapticsEnabled ? "Core Haptics • FFT 30–150 Гц" : "Вибрация выключена")
                .font(.caption)
                .foregroundColor(.white.opacity(0.45))
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(spacing: 4) {
            Slider(
                value: sliderBinding,
                in: 0...max(player.duration, 0.01),
                onEditingChanged: { editing in
                    if editing {
                        isScrubbing = true
                        scrubValue = player.position
                    } else {
                        isScrubbing = false
                        player.seek(to: scrubValue)
                        HapticsManager.shared.uiTap()
                    }
                }
            )
            .tint(Theme.gold)
            .disabled(player.duration <= 0)

            HStack {
                Text(MusicPlayerEngine.timeString(isScrubbing ? scrubValue : player.position))
                    .frame(minWidth: 44, alignment: .leading)
                Spacer()
                Text("-" + MusicPlayerEngine.timeString(max(0, player.duration - (isScrubbing ? scrubValue : player.position))))
                    .frame(minWidth: 44, alignment: .trailing)
            }
            .font(.caption2.monospacedDigit())
            .foregroundColor(.white.opacity(0.40))
        }
    }

    // MARK: - Transport

    private var transport: some View {
        HStack(spacing: 34) {
            Button {
                HapticsManager.shared.uiTap()
                player.skip(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
            }
            .buttonStyle(PressableButtonStyle())

            Button {
                HapticsManager.shared.uiTap()
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.goldGradient)
                        .frame(width: 78, height: 78)
                        .shadow(color: Theme.gold.opacity(0.35), radius: 22, y: 8)

                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Theme.ink)
                        .offset(x: player.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(PressableButtonStyle(scale: 0.92))

            Button {
                HapticsManager.shared.uiTap()
                player.skip(by: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.vertical, 2)
    }

    // MARK: - Library

    private var libraryCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionCaption(text: "Библиотека")
                    Spacer()
                    Text("\(player.tracks.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white.opacity(0.35))
                }

                if player.tracks.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 2) {
                        ForEach(player.tracks) { track in
                            trackRow(track)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 26, weight: .regular))
                .foregroundColor(.white.opacity(0.35))

            Text("Пока нет треков")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))

            Text("Импортируйте MP3, WAV, M4A или FLAC из приложения «Файлы»")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.40))
                .multilineTextAlignment(.center)

            Button {
                HapticsManager.shared.uiTap()
                showImporter = true
            } label: {
                Text("Импортировать музыку")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private func trackRow(_ track: Track) -> some View {
        let isCurrent = player.isCurrent(track)

        return HStack(spacing: 12) {
            Button {
                HapticsManager.shared.uiTap()
                if isCurrent {
                    player.togglePlayPause()
                } else {
                    player.play(track)
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(isCurrent ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.07)))
                            .frame(width: 42, height: 42)

                        Image(systemName: isCurrent && player.isPlaying ? "waveform" : "music.note")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(isCurrent ? 0.95 : 0.55))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                            .foregroundColor(.white.opacity(isCurrent ? 1 : 0.86))
                            .lineLimit(1)

                        Text(track.duration > 0 ? track.durationText : "—")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.white.opacity(0.35))
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(scale: 0.99))

            Menu {
                Button(role: .destructive) {
                    player.delete(track)
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(width: 30, height: 34)
                    .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 5)
    }
}
