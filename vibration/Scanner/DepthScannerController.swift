import Foundation
import UIKit
import ARKit
import SceneKit
import AVFoundation
import QuartzCore

/// Which depth sensor the scanner talks to.
enum ScannerMode: String, CaseIterable, Identifiable {
    case rear
    case front

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rear: return "Задний LiDAR"
        case .front: return "Фронтальный"
        }
    }

    var shortTitle: String {
        switch self {
        case .rear: return "LiDAR"
        case .front: return "Лицо"
        }
    }

    var sensorName: String {
        switch self {
        case .rear: return "LiDAR + камера"
        case .front: return "TrueDepth"
        }
    }

    var hint: String {
        switch self {
        case .rear:
            return "Наведите перекрестие в центре на стену или предмет"
        case .front:
            return "Держите лицо внутри овала"
        }
    }

    var rangeText: String {
        switch self {
        case .rear: return "0.2 – 5 м"
        case .front: return "0.15 – 1.2 м"
        }
    }
}

/// Drives one `ARSCNView` in either world-tracking (rear LiDAR) or
/// face-tracking (front TrueDepth) mode and turns the session into a single
/// smoothed distance reading plus optional proximity haptics.
final class DepthScannerController: NSObject, ObservableObject, ARSCNViewDelegate {

    // MARK: - Published state

    @Published private(set) var distance: Double?
    @Published private(set) var mode: ScannerMode = .rear
    @Published private(set) var availableModes: [ScannerMode] = []
    @Published private(set) var isRunning = false
    @Published private(set) var statusText: String = ""
    @Published private(set) var cameraDenied = false
    @Published private(set) var trackingNormal = true
    @Published private(set) var sensorsDescription: String = ""

    // MARK: - Private

    private weak var sceneView: ARSCNView?
    private var timer: Timer?

    private var smoothedDistance: Double?
    private var lastValueTime: CFTimeInterval = 0

    private var latestFaceDistance: Double?
    private var latestFaceTime: CFTimeInterval = 0

    private var lastTickTime: CFTimeInterval = 0
    private var isRequestingPermission = false
    /// True while the Lidar tab is on screen; lets a late `attach` still start
    /// the session if SwiftUI built the view after `onAppear`.
    private var wantsToRun = false

    override init() {
        super.init()

        var modes: [ScannerMode] = []
        var sensors: [String] = []

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            modes.append(.rear)
            sensors.append("задний LiDAR")
        }
        if ARFaceTrackingConfiguration.isSupported {
            modes.append(.front)
            sensors.append("фронтальный TrueDepth")
        }

        availableModes = modes
        if let first = modes.first {
            mode = first
        }
        sensorsDescription = sensors.isEmpty ? "не обнаружены" : sensors.joined(separator: " + ")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleDidEnterBackground() {
        stopSession()
    }

    @objc private func handleWillEnterForeground() {
        if wantsToRun {
            activate()
        }
    }

    // MARK: - Lifecycle

    func attach(_ view: ARSCNView) {
        if sceneView === view {
            if wantsToRun, !isRunning { startSession() }
            return
        }
        sceneView = view
        view.delegate = self
        view.automaticallyUpdatesLighting = false
        if wantsToRun, !isRunning { startSession() }
    }

    /// Called by the view's `onAppear`.
    func activate() {
        wantsToRun = true
        guard !availableModes.isEmpty else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraDenied = false
            startSession()

        case .notDetermined:
            guard !isRequestingPermission else { return }
            isRequestingPermission = true
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isRequestingPermission = false
                    if granted {
                        self.cameraDenied = false
                        self.startSession()
                    } else {
                        self.cameraDenied = true
                        self.statusText = "Нет доступа к камере"
                    }
                }
            }

        default:
            cameraDenied = true
            statusText = "Нет доступа к камере"
        }
    }

    /// Called when the tab is left — ARKit must be paused to save power.
    func deactivate() {
        wantsToRun = false
        stopSession()
    }

    func select(_ newMode: ScannerMode) {
        guard newMode != mode, availableModes.contains(newMode) else { return }
        let shouldRestart = isRunning
        stopSession()
        mode = newMode
        resetReadings()

        if shouldRestart || sceneView != nil {
            startSession()
        }
    }

    // MARK: - Session

    private func startSession() {
        guard let view = sceneView, !isRunning, !availableModes.isEmpty else { return }

        isRunning = true
        resetReadings()
        statusText = mode.hint

        switch mode {
        case .front:
            let configuration = ARFaceTrackingConfiguration()
            configuration.isLightEstimationEnabled = false
            configuration.maximumNumberOfTrackedFaces = 1
            view.debugOptions = []
            view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        case .rear:
            let configuration = ARWorldTrackingConfiguration()
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
            }
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.environmentTexturing = .none
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                configuration.frameSemantics.insert(.sceneDepth)
            }
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                // Point-cloud feedback while the scene mesh is being built.
                view.debugOptions = [.showFeaturePoints]
            } else {
                view.debugOptions = []
            }
            view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }

        startTimer()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func stopSession() {
        timer?.invalidate()
        timer = nil

        sceneView?.session.pause()
        sceneView?.debugOptions = []

        isRunning = false
        UIApplication.shared.isIdleTimerDisabled = false
        resetReadings()
    }

    private func resetReadings() {
        smoothedDistance = nil
        latestFaceDistance = nil
        distance = nil
    }

    private func startTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.sampleDistance()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    // MARK: - Sampling

    private func sampleDistance() {
        guard isRunning, let view = sceneView else { return }
        let now = CACurrentMediaTime()

        var raw: Double?
        switch mode {
        case .front:
            if let face = latestFaceDistance, now - latestFaceTime < 0.6 {
                raw = face
            }
        case .rear:
            raw = raycastDistance(in: view)
        }

        guard let value = raw else {
            if smoothedDistance != nil, now - lastValueTime > 1.0 {
                smoothedDistance = nil
                distance = nil
                statusText = mode.hint
            }
            return
        }

        lastValueTime = now

        if let previous = smoothedDistance {
            smoothedDistance = previous * 0.70 + value * 0.30
        } else {
            smoothedDistance = value
        }

        let result = smoothedDistance ?? value
        distance = result

        updateProximityHaptics(distance: result, now: now)
    }

    private func raycastDistance(in view: ARSCNView) -> Double? {
        guard view.bounds.width > 1, view.bounds.height > 1 else { return nil }
        let point = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let query = view.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any) else {
            return nil
        }
        let hits = view.session.raycast(query)
        guard let hit = hits.first, let frame = view.session.currentFrame else { return nil }

        let camera = frame.camera.transform.columns.3
        let target = hit.worldTransform.columns.3
        let dx = Double(target.x - camera.x)
        let dy = Double(target.y - camera.y)
        let dz = Double(target.z - camera.z)
        let value = (dx * dx + dy * dy + dz * dz).squareRoot()
        return value > 0.05 ? value : nil
    }

    // MARK: - Proximity haptics ("парктроник")

    private func updateProximityHaptics(distance value: Double, now: CFTimeInterval) {
        guard AppSettings.shared.proximityHaptics else { return }

        let nearDistance = 0.12
        let farDistance = 1.20
        guard value < farDistance else { return }

        let closeness = max(0, min(1, (farDistance - value) / (farDistance - nearDistance)))
        let interval = 0.62 - 0.52 * closeness

        guard now - lastTickTime >= interval else { return }
        lastTickTime = now
        HapticsManager.shared.tick(intensity: CGFloat(0.25 + 0.75 * closeness))
    }

    // MARK: - ARSCNViewDelegate

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        guard faceAnchor.isTracked else { return }
        guard let frame = sceneView?.session.currentFrame else { return }

        // ARKit places the face in world space, so measure the euclidean
        // distance to the *current* camera, not the world origin: the phone
        // itself moves while the user scans.
        let camera = frame.camera.transform.columns.3
        let face = faceAnchor.transform.columns.3
        let dx = Double(face.x - camera.x)
        let dy = Double(face.y - camera.y)
        let dz = Double(face.z - camera.z)
        let depth = (dx * dx + dy * dy + dz * dz).squareRoot()

        if depth > 0.02, depth < 2.0 {
            latestFaceDistance = depth
            latestFaceTime = CACurrentMediaTime()
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async {
            switch camera.trackingState {
            case .normal:
                self.trackingNormal = true
            case .notAvailable:
                self.trackingNormal = false
            case .limited:
                self.trackingNormal = false
            }
        }
    }

    // MARK: - Formatting

    var distanceText: String {
        guard let value = distance else { return "—" }
        if value < 1 {
            let centimeters = Int((value * 100).rounded())
            return "\(centimeters) см"
        }
        return String(format: "%.2f м", value)
    }

    var distanceDetail: String {
        guard let value = distance else { return "нет данных" }
        return String(format: "%.2f м", value)
    }

    var proximityRateText: String {
        guard let value = distance else {
            return "Наведите камеру, чтобы включить тики"
        }
        let nearDistance = 0.12
        let farDistance = 1.20
        if value >= farDistance {
            return "Слишком далеко — тики выключены"
        }
        let closeness = max(0, min(1, (farDistance - value) / (farDistance - nearDistance)))
        let interval = 0.62 - 0.52 * closeness
        return "Тик примерно каждые \(Int((interval * 1000).rounded())) мс"
    }

    var isAvailable: Bool {
        !availableModes.isEmpty
    }
}
