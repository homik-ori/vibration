import SwiftUI

/// Root tab container. Switching tabs stops the AR session and the audio
/// engine so neither keeps the camera or the CPU busy in the background.
struct RootView: View {
    @StateObject private var player = MusicPlayerEngine()
    @StateObject private var scanner = DepthScannerController()
    @State private var selection: Int = 0

    var body: some View {
        TabView(selection: $selection) {
            MusicPlayerView(player: player)
                .background(AppBackground())
                .tabItem {
                    Label("Музыка", systemImage: "waveform")
                }
                .tag(0)

            LidarScannerView(scanner: scanner)
                .background(AppBackground())
                .tabItem {
                    Label("Лидар", systemImage: "cube.transparent")
                }
                .tag(1)

            TapPadView()
                .background(AppBackground())
                .tabItem {
                    Label("Тап", systemImage: "hand.tap.fill")
                }
                .tag(2)

            SettingsView()
                .background(AppBackground())
                .tabItem {
                    Label("Настройки", systemImage: "slider.horizontal.3")
                }
                .tag(3)
        }
        .onChange(of: selection) { newValue in
            if newValue != 0 {
                player.suspend()
            }
            if newValue != 1 {
                scanner.deactivate()
            }
            if newValue == 0 {
                player.applySettings()
            }
            if newValue == 1 {
                scanner.activate()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
    }
}

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .preferredColorScheme(.dark)
    }
}
#endif
