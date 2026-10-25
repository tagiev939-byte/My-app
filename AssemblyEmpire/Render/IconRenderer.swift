import SceneKit
import UIKit
import Metal

/// Renders 3D models into small images for the SwiftUI interface.
final class IconRenderer {
    private let renderer: SCNRenderer
    private let scene = SCNScene()
    private let holder = SCNNode()
    private let cameraNode = SCNNode()

    init() {
        renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = Tex.sky
        scene.lightingEnvironment.intensity = 1.4

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1500
        key.light?.color = UIColor(red: 1, green: 0.96, blue: 0.9, alpha: 1)
        key.eulerAngles = SCNVector3(-0.9, 0.5, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .ambient
        fill.light?.intensity = 300
        scene.rootNode.addChildNode(fill)

        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.zNear = 0.01
        cam.zFar = 50
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(holder)

        renderer.scene = scene
        renderer.pointOfView = cameraNode
        renderer.autoenablesDefaultLighting = false
    }

    func render(_ node: SCNNode, size: CGFloat = 150, yaw: Float = 0.62, pitch: Float = 0.62) -> UIImage {
        holder.childNodes.forEach { $0.removeFromParentNode() }
        holder.addChildNode(node)
        let (minB, maxB) = node.boundingBox
        let center = SCNVector3((minB.x + maxB.x) / 2, (minB.y + maxB.y) / 2, (minB.z + maxB.z) / 2)
        let ext = max(maxB.x - minB.x, maxB.y - minB.y, maxB.z - minB.z)
        let dist: Float = 10
        cameraNode.position = SCNVector3(center.x + sin(yaw) * cos(pitch) * dist,
                                         center.y + sin(pitch) * dist,
                                         center.z + cos(yaw) * cos(pitch) * dist)
        cameraNode.look(at: center)
        cameraNode.camera?.orthographicScale = Double(ext) * 0.68
        let img = renderer.snapshot(atTime: 0, with: CGSize(width: size, height: size), antialiasingMode: .multisampling4X)
        holder.childNodes.forEach { $0.removeFromParentNode() }
        return img
    }
}
