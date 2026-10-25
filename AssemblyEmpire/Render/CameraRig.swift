import SceneKit
import simd
import UIKit

/// Orbit camera: target on the ground, yaw around Y, pitch that depends on zoom.
final class CameraRig {
    let root = SCNNode()
    let yawNode = SCNNode()
    let pitchNode = SCNNode()
    let cameraNode = SCNNode()
    let camera = SCNCamera()

    var target = SIMD3<Float>(24.5, 0, 23)
    var goalTarget = SIMD3<Float>(24.5, 0, 23)
    var yaw: Float = 0.5
    var goalYaw: Float = 0.5
    var distance: Float = 15
    var goalDistance: Float = 15
    var orbiting = false
    var velocity = SIMD3<Float>(repeating: 0)

    static let minDistance: Float = 5
    static let maxDistance: Float = 60
    static let fov: Float = 40

    init() {
        camera.fieldOfView = CGFloat(CameraRig.fov)
        camera.zNear = 0.1
        camera.zFar = 400
        cameraNode.camera = camera
        root.addChildNode(yawNode)
        yawNode.addChildNode(pitchNode)
        pitchNode.addChildNode(cameraNode)
        apply()
    }

    var pitch: Float {
        let t = (distance - CameraRig.minDistance) / (CameraRig.maxDistance - CameraRig.minDistance)
        return 0.6 + 0.55 * max(0, min(1, t))
    }

    func apply() {
        root.simdPosition = target
        yawNode.simdEulerAngles = SIMD3(0, yaw, 0)
        pitchNode.simdEulerAngles = SIMD3(-pitch, 0, 0)
        cameraNode.simdPosition = SIMD3(0, 0, distance)
    }

    /// Keeps the map gliding after a quick swipe.
    func fling(_ v: SIMD3<Float>) {
        let speed = simd_length(v)
        guard speed > 1.5 else { return }
        velocity = speed > 60 ? v / speed * 60 : v
    }

    func update(_ dt: Double) {
        if orbiting { goalYaw += Float(dt) * 0.07 }
        if simd_length(velocity) > 0.05 {
            goalTarget = clamp(goalTarget + velocity * Float(dt))
            target = goalTarget
            velocity *= Float(exp(-dt * 4.5))
        } else {
            velocity = .zero
        }
        let k = Float(1 - exp(-dt * 7))
        target += (goalTarget - target) * k
        yaw += (goalYaw - yaw) * k
        distance += (goalDistance - distance) * k
        apply()
    }

    private func clamp(_ p: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(min(max(p.x, 1), Float(World.size) - 1), 0, min(max(p.z, 1), Float(World.size) - 1))
    }

    func pan(by d: SIMD3<Float>) {
        goalTarget = clamp(target + SIMD3(d.x, 0, d.z))
        target = goalTarget
        apply()
    }

    func zoom(scale: Float) {
        guard scale > 0 else { return }
        goalDistance = min(max(distance / scale, CameraRig.minDistance), CameraRig.maxDistance)
        distance = goalDistance
        apply()
    }

    func rotate(by a: Float) {
        goalYaw = yaw + a
        yaw = goalYaw
        apply()
    }

    func focus(_ p: SIMD3<Float>, distance d: Float? = nil) {
        goalTarget = clamp(p)
        if let d { goalDistance = min(max(d, CameraRig.minDistance), CameraRig.maxDistance) }
    }

    func snap() {
        target = goalTarget
        yaw = goalYaw
        distance = goalDistance
        apply()
    }

    /// Ray through a screen point (in view points), computed from the model transform.
    func ray(_ p: CGPoint, viewSize: CGSize) -> (origin: SIMD3<Float>, dir: SIMD3<Float>) {
        let w = Float(max(viewSize.width, 1)), h = Float(max(viewSize.height, 1))
        let nx = 2 * Float(p.x) / w - 1
        let ny = 1 - 2 * Float(p.y) / h
        let tanHalf = tan(CameraRig.fov * Float.pi / 180 / 2)
        let local = simd_normalize(SIMD3<Float>(nx * tanHalf * (w / h), ny * tanHalf, -1))
        let m = cameraNode.simdWorldTransform
        let origin = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        let dir4 = m * SIMD4<Float>(local.x, local.y, local.z, 0)
        return (origin, simd_normalize(SIMD3(dir4.x, dir4.y, dir4.z)))
    }

    func ground(_ p: CGPoint, viewSize: CGSize, y: Float = 0) -> SIMD3<Float>? {
        let r = ray(p, viewSize: viewSize)
        guard abs(r.dir.y) > 1e-5 else { return nil }
        let t = (y - r.origin.y) / r.dir.y
        guard t > 0 else { return nil }
        return r.origin + r.dir * t
    }
}
