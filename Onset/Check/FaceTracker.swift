import ARKit
import AVFoundation
import SceneKit
import SwiftUI

/// Reads the TrueDepth face mesh (the same sensor as Face ID) 60 times a second
/// and exposes the left/right muscle activations ARKit estimates for the mouth.
final class FaceTracker: NSObject, ObservableObject, ARSCNViewDelegate {
    struct Sample {
        let smileLeft: Double
        let smileRight: Double
        let frownLeft: Double
        let frownRight: Double
        let stretchLeft: Double
        let stretchRight: Double
    }

    @Published var faceVisible = false
    /// True when the camera can't be used (permission refused or ARKit failed).
    @Published var failed = false
    @Published var latest = Sample(smileLeft: 0, smileRight: 0, frownLeft: 0, frownRight: 0, stretchLeft: 0, stretchRight: 0)

    let sceneView = ARSCNView(frame: .zero)
    private var recording = false
    private var samples: [Sample] = []
    private let lock = NSLock()

    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    override init() {
        super.init()
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.backgroundColor = .black
    }

    func start() {
        guard Self.isSupported else { return }
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                guard granted else { self.failed = true; return }
                let config = ARFaceTrackingConfiguration()
                config.isLightEstimationEnabled = true
                self.sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.failed = true }
    }

    func stop() {
        sceneView.session.pause()
    }

    func beginRecording() {
        lock.lock(); samples = []; recording = true; lock.unlock()
    }

    func endRecording() -> [Sample] {
        lock.lock(); defer { lock.unlock() }
        recording = false
        return samples
    }

    // MARK: ARSCNViewDelegate

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor is ARFaceAnchor,
              let device = sceneView.device,
              let geometry = ARSCNFaceGeometry(device: device) else { return nil }
        let material = geometry.firstMaterial
        material?.fillMode = .lines
        material?.diffuse.contents = UIColor(red: 0.45, green: 0.85, blue: 1.0, alpha: 0.85)
        material?.lightingModel = .constant
        return SCNNode(geometry: geometry)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let face = anchor as? ARFaceAnchor else { return }
        (node.geometry as? ARSCNFaceGeometry)?.update(from: face.geometry)

        let b = face.blendShapes
        func v(_ key: ARFaceAnchor.BlendShapeLocation) -> Double { b[key]?.doubleValue ?? 0 }
        let sample = Sample(smileLeft: v(.mouthSmileLeft), smileRight: v(.mouthSmileRight),
                            frownLeft: v(.mouthFrownLeft), frownRight: v(.mouthFrownRight),
                            stretchLeft: v(.mouthStretchLeft), stretchRight: v(.mouthStretchRight))

        lock.lock()
        if recording { samples.append(sample) }
        lock.unlock()

        let tracked = face.isTracked
        DispatchQueue.main.async {
            self.latest = sample
            self.faceVisible = tracked
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async { self.faceVisible = false }
    }

    // MARK: Analysis

    static func measure(rest: [Sample], smile: [Sample]) -> FaceMeasurement? {
        guard !smile.isEmpty else { return nil }

        // Use the strongest part of the smile (top 40% of frames by total smile).
        let ranked = smile.sorted { ($0.smileLeft + $0.smileRight) > ($1.smileLeft + $1.smileRight) }
        let top = Array(ranked.prefix(max(3, ranked.count * 4 / 10)))
        let l = top.map { ($0.smileLeft + $0.stretchLeft * 0.5) }.average
        let r = top.map { ($0.smileRight + $0.stretchRight * 0.5) }.average
        let smileAsym = abs(l - r) / max(max(l, r), 0.15)

        var restAsym = 0.0
        if !rest.isEmpty {
            let sl = rest.map(\.smileLeft).average, sr = rest.map(\.smileRight).average
            let fl = rest.map(\.frownLeft).average, fr = rest.map(\.frownRight).average
            // A drooping corner shows up as one-sided frown / missing tone at rest.
            restAsym = min(1, (abs(sl - sr) + abs(fl - fr)) * 1.5)
        }
        return FaceMeasurement(smileAsymmetry: min(1, smileAsym), restAsymmetry: restAsym,
                               leftSmile: l, rightSmile: r)
    }
}

extension Array where Element == Double {
    var average: Double { isEmpty ? 0 : reduce(0, +) / Double(count) }
    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let m = average
        return (map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(count - 1)).squareRoot()
    }
}

struct FaceMeshView: UIViewRepresentable {
    let tracker: FaceTracker
    func makeUIView(context: Context) -> ARSCNView { tracker.sceneView }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
