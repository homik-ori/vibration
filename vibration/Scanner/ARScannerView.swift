import SwiftUI
import ARKit
import SceneKit

/// Hosts the live `ARSCNView`. The controller owns all session decisions; this
/// wrapper only builds the view once and re-attaches it if SwiftUI recreates it.
struct ARScannerView: UIViewRepresentable {
    let controller: DepthScannerController

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.backgroundColor = .black
        view.scene = SCNScene()
        view.autoenablesDefaultLighting = false
        view.automaticallyUpdatesLighting = false
        view.antialiasingMode = .none
        view.preferredFramesPerSecond = 60
        view.isUserInteractionEnabled = false
        controller.attach(view)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        controller.attach(uiView)
    }
}
