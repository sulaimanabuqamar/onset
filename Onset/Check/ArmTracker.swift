import CoreMotion
import SwiftUI

/// Pronator drift test with the phone as the instrument:
/// the phone lies flat on the palm, arm straight out, eyes closed, 10 seconds.
/// A weak arm slowly sinks and turns palm-down — the phone feels both as tilt.
final class ArmTracker: ObservableObject {
    @Published var tiltX: Double = 0      // for the live "spirit level"
    @Published var tiltY: Double = 0
    @Published var currentDrift: Double = 0

    private let motion = CMMotionManager()
    private var reference: CMAcceleration?
    private var maxDrift = 0.0
    private var accel: [Double] = []
    private var measuring = false

    var isAvailable: Bool { motion.isDeviceMotionAvailable }

    func startPreview() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 50.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.handle(data)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    /// Call once the arm is up and still: the current position becomes "zero".
    func beginMeasuring() {
        reference = motion.deviceMotion?.gravity
        maxDrift = 0
        accel = []
        measuring = true
    }

    /// Returns (largest drift in degrees, tremor).
    func endMeasuring() -> (drift: Double, tremor: Double) {
        measuring = false
        return (maxDrift, accel.standardDeviation)
    }

    private func handle(_ data: CMDeviceMotion) {
        let g = data.gravity
        let ref = reference ?? g
        let angle = Self.angle(between: g, and: ref)
        tiltX = g.x - ref.x
        tiltY = g.y - ref.y
        currentDrift = measuring ? angle : 0
        if measuring {
            maxDrift = max(maxDrift, angle)
            let a = data.userAcceleration
            accel.append((a.x * a.x + a.y * a.y + a.z * a.z).squareRoot())
        }
    }

    static func angle(between a: CMAcceleration, and b: CMAcceleration) -> Double {
        let dot = a.x * b.x + a.y * b.y + a.z * b.z
        let na = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
        let nb = (b.x * b.x + b.y * b.y + b.z * b.z).squareRoot()
        guard na > 0, nb > 0 else { return 0 }
        let c = Swift.max(-1.0, Swift.min(1.0, dot / (na * nb)))
        return acos(c) * 180 / .pi
    }
}
