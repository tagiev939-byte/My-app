import SceneKit
import simd
import UIKit

/// Orbit camera around the restaurant: target on the ground, limited yaw, pitch that follows zoom.
/// The field of view is horizontal so the restaurant fills the width of any phone.
final class CameraRig {
    let root = SCNNode()
    let yawNode = SCNNode()
    let pitchNode = SCNNode()
    let cameraNode = SCNNode()
    let camera = SCNCamera()

    static let home = SIMD3<Float>(0, 0, 1.3)
    static let homeDistance: Float = 22
    static let minDistance: Float = 8
    static let maxDistance: Float = 32
    static let fov: Float = 30

    var target = CameraRig.home
    var goalTarget = CameraRig.home
    var yaw: Float = 0
    var goalYaw: Float = 0
    var distance: Float = CameraRig.homeDistance
    var goalDistance: Float = CameraRig.homeDistance
    var velocity = SIMD3<Float>(repeating: 0)
    var shake: Float = 0
    var idleSway = true
    private var swayTime: Double = 0

    init() {
        camera.fieldOfView = CGFloat(CameraRig.fov)
        camera.projectionDirection = .horizontal
        camera.zNear = 0.2
        camera.zFar = 300
        cameraNode.camera = camera
        root.addChildNode(yawNode)
        yawNode.addChildNode(pitchNode)
        pitchNode.addChildNode(cameraNode)
        apply()
    }

    var pitch: Float {
        let t = (distance - CameraRig.minDistance) / (CameraRig.maxDistance - CameraRig.minDistance)
        return 0.8 + 0.32 * max(0, min(1, t))
    }

    func apply() {
        var p = target
        var y = yaw
        if shake > 0 {
            p += SIMD3(Float.random(in: -1...1), 0, Float.random(in: -1...1)) * shake * 0.08
        }
        if idleSway { y += Float(sin(swayTime * 0.11)) * 0.035 }
        root.simdPosition = p
        yawNode.simdEulerAngles = SIMD3(0, y, 0)
        pitchNode.simdEulerAngles = SIMD3(-pitch, 0, 0)
        cameraNode.simdPosition = SIMD3(0, 0, distance)
    }

    func fling(_ v: SIMD3<Float>) {
        let speed = simd_length(v)
        guard speed > 1.5 else { return }
        velocity = speed > 40 ? v / speed * 40 : v
    }

    func update(_ dt: Double) {
        swayTime += dt
        if shake > 0 { shake = max(0, shake - Float(dt) * 2.5) }
        if simd_length(velocity) > 0.05 {
            goalTarget = clamp(goalTarget + velocity * Float(dt))
            target = goalTarget
            velocity *= Float(exp(-dt * 5))
        } else {
            velocity = .zero
        }
        let k = Float(1 - exp(-dt * 6))
        target += (goalTarget - target) * k
        yaw += (goalYaw - yaw) * k
        distance += (goalDistance - distance) * k
        apply()
    }

    private func clamp(_ p: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(min(max(p.x, -8), 8), 0, min(max(p.z, -2.5), 8.5))
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
        goalYaw = min(max(yaw + a, -0.85), 0.85)
        yaw = goalYaw
        apply()
    }

    func focus(_ p: SIMD3<Float>, distance d: Float? = nil, yaw y: Float? = nil) {
        goalTarget = clamp(p)
        if let d { goalDistance = min(max(d, CameraRig.minDistance), CameraRig.maxDistance) }
        if let y { goalYaw = y }
    }

    func reset() {
        focus(CameraRig.home, distance: CameraRig.homeDistance, yaw: 0)
    }

    func snap() {
        target = goalTarget
        yaw = goalYaw
        distance = goalDistance
        apply()
    }

    /// Ray through a screen point (in view points).
    func ray(_ p: CGPoint, viewSize: CGSize) -> (origin: SIMD3<Float>, dir: SIMD3<Float>) {
        let w = Float(max(viewSize.width, 1)), h = Float(max(viewSize.height, 1))
        let nx = 2 * Float(p.x) / w - 1
        let ny = 1 - 2 * Float(p.y) / h
        let tanX = tan(CameraRig.fov * Float.pi / 180 / 2)
        let tanY = tanX * h / w
        let local = simd_normalize(SIMD3<Float>(nx * tanX, ny * tanY, -1))
        let m = cameraNode.simdWorldTransform
        let origin = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        let dir4 = m * SIMD4<Float>(local.x, local.y, local.z, 0)
        return (origin, simd_normalize(SIMD3(dir4.x, dir4.y, dir4.z)))
    }

    func ground(_ p: CGPoint, viewSize: CGSize, y: Float = 0) -> SIMD3<Float>? {
        let r = ray(p, viewSize: viewSize)
        guard abs(r.dir.y) > 1e-5 else { return nil }
        let t = (y - r.origin.y) / r.dir.y
        guard t > 0, t < 400 else { return nil }
        return r.origin + r.dir * t
    }
}
