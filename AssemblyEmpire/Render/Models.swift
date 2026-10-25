import SceneKit
import UIKit
import simd

// MARK: - Materials

final class MaterialCache {
    static let shared = MaterialCache()
    private var cache: [String: SCNMaterial] = [:]

    func pbr(_ hex: UInt32, rough: CGFloat = 0.6, metal: CGFloat = 0, emission: UInt32? = nil,
             glow: CGFloat = 1, alpha: CGFloat = 1) -> SCNMaterial {
        let key = "\(hex)|\(rough)|\(metal)|\(emission ?? 0)|\(glow)|\(alpha)"
        if let m = cache[key] { return m }
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(hex: hex)
        m.roughness.contents = NSNumber(value: Double(rough))
        m.metalness.contents = NSNumber(value: Double(metal))
        if let e = emission {
            m.emission.contents = UIColor(hex: e)
            m.emission.intensity = glow
        }
        if alpha < 1 {
            m.transparency = alpha
            m.blendMode = .alpha
        }
        cache[key] = m
        return m
    }

    func textured(_ key: String, _ image: UIImage, rough: CGFloat = 0.8, metal: CGFloat = 0) -> SCNMaterial {
        if let m = cache[key] { return m }
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = image
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.mipFilter = .linear
        m.roughness.contents = NSNumber(value: Double(rough))
        m.metalness.contents = NSNumber(value: Double(metal))
        cache[key] = m
        return m
    }
}

/// Shared palette of materials.
enum M {
    static var c: MaterialCache { MaterialCache.shared }
    static var steelDark: SCNMaterial { c.pbr(0x3A414C, rough: 0.55, metal: 0.45) }
    static var steel: SCNMaterial { c.pbr(0x7C8794, rough: 0.4, metal: 0.7) }
    static var chrome: SCNMaterial { c.pbr(0xD8DEE6, rough: 0.22, metal: 0.95) }
    static var frame: SCNMaterial { c.pbr(0x30353D, rough: 0.6, metal: 0.3) }
    static var rail: SCNMaterial { c.pbr(0x9AA3AE, rough: 0.35, metal: 0.75) }
    static var yellow: SCNMaterial { c.pbr(0xF2B33D, rough: 0.45, metal: 0.15) }
    static var brick: SCNMaterial { c.pbr(0xB4523A, rough: 0.85) }
    static var stoneGray: SCNMaterial { c.pbr(0x6E7178, rough: 0.9) }
    static var roof: SCNMaterial { c.pbr(0x3B3F46, rough: 0.7, metal: 0.2) }
    static var blue: SCNMaterial { c.pbr(0x3C7FC2, rough: 0.45, metal: 0.25) }
    static var purple: SCNMaterial { c.pbr(0x7A5CC7, rough: 0.5, metal: 0.2) }
    static var green: SCNMaterial { c.pbr(0x3C9A5F, rough: 0.7) }
    static var cream: SCNMaterial { c.pbr(0xF3E9D2, rough: 0.85) }
    static var terracotta: SCNMaterial { c.pbr(0xC8553D, rough: 0.75) }
    static var wood: SCNMaterial { c.pbr(0x9C6B43, rough: 0.9) }
    static var woodDark: SCNMaterial { c.pbr(0x6E4A2E, rough: 0.9) }
    static var gold: SCNMaterial { c.pbr(0xF5C542, rough: 0.28, metal: 0.95) }
    static var goldDark: SCNMaterial { c.pbr(0xC9971F, rough: 0.35, metal: 0.95) }
    static var white: SCNMaterial { c.pbr(0xF0F3F7, rough: 0.4, metal: 0.1) }
    static var black: SCNMaterial { c.pbr(0x1C1E22, rough: 0.5, metal: 0.2) }
    static var arrow: SCNMaterial { c.pbr(0xFFFFFF, rough: 0.5, emission: 0xFFFFFF, glow: 0.35) }
    static var cyanGlow: SCNMaterial { c.pbr(0x6FD8FF, rough: 0.3, emission: 0x5FD0FF, glow: 1.2) }
    static var furnaceGlow: SCNMaterial { c.pbr(0xFF8A2A, rough: 0.4, emission: 0xFF7A1A, glow: 0.3) }
    static var redLight: SCNMaterial { c.pbr(0x55FF7A, rough: 0.3, emission: 0x3DFF6A, glow: 0.2) }
    static var window: SCNMaterial { c.pbr(0xFFE7A8, rough: 0.2, emission: 0xFFD27A, glow: 0.6) }
    static var awning: SCNMaterial { c.textured("stripes", Tex.stripes, rough: 0.8) }
    static var hazard: SCNMaterial { c.textured("hazard", Tex.hazard, rough: 0.7) }
    static var rubber: SCNMaterial { c.pbr(0x2A2D33, rough: 0.9) }
    static var trunk: SCNMaterial { c.pbr(0x7A5133, rough: 0.95) }
    static var leaves: SCNMaterial { c.pbr(0x4E9A3E, rough: 0.85) }
    static var leaves2: SCNMaterial { c.pbr(0x3E8A47, rough: 0.85) }
    static var leaves3: SCNMaterial { c.pbr(0x6DAA3E, rough: 0.85) }
    static var highlight: SCNMaterial { c.pbr(0xFFD54A, rough: 0.4, emission: 0xFFC83A, glow: 1.0) }
}

// MARK: - Geometry helpers

extension SCNNode {
    @discardableResult
    func at(_ x: Float, _ y: Float, _ z: Float) -> SCNNode {
        position = SCNVector3(x, y, z)
        return self
    }

    @discardableResult
    func rot(_ x: Float, _ y: Float, _ z: Float) -> SCNNode {
        eulerAngles = SCNVector3(x, y, z)
        return self
    }

    @discardableResult
    func named(_ n: String) -> SCNNode {
        name = n
        return self
    }

    func add(_ nodes: SCNNode...) {
        for n in nodes { addChildNode(n) }
    }
}

enum Geo {
    static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ m: SCNMaterial, chamfer: CGFloat = 0) -> SCNNode {
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: chamfer)
        if chamfer > 0 { g.chamferSegmentCount = 2 }
        g.materials = [m]
        return SCNNode(geometry: g)
    }

    static func cylinder(_ r: CGFloat, _ h: CGFloat, _ m: SCNMaterial, segments: Int = 20) -> SCNNode {
        let g = SCNCylinder(radius: r, height: h)
        g.radialSegmentCount = segments
        g.materials = [m]
        return SCNNode(geometry: g)
    }

    static func cone(_ top: CGFloat, _ bottom: CGFloat, _ h: CGFloat, _ m: SCNMaterial, segments: Int = 20) -> SCNNode {
        let g = SCNCone(topRadius: top, bottomRadius: bottom, height: h)
        g.radialSegmentCount = segments
        g.materials = [m]
        return SCNNode(geometry: g)
    }

    static func sphere(_ r: CGFloat, _ m: SCNMaterial, segments: Int = 16) -> SCNNode {
        let g = SCNSphere(radius: r)
        g.segmentCount = segments
        g.materials = [m]
        return SCNNode(geometry: g)
    }

    static func tube(_ inner: CGFloat, _ outer: CGFloat, _ h: CGFloat, _ m: SCNMaterial) -> SCNNode {
        let g = SCNTube(innerRadius: inner, outerRadius: outer, height: h)
        g.radialSegmentCount = 24
        g.materials = [m]
        return SCNNode(geometry: g)
    }

    static func torus(_ ring: CGFloat, _ pipe: CGFloat, _ m: SCNMaterial) -> SCNNode {
        let g = SCNTorus(ringRadius: ring, pipeRadius: pipe)
        g.ringSegmentCount = 24
        g.pipeSegmentCount = 10
        g.materials = [m]
        return SCNNode(geometry: g)
    }

    static func node(_ g: SCNGeometry, _ m: SCNMaterial) -> SCNNode {
        g.materials = [m]
        return SCNNode(geometry: g)
    }

    /// Flat-shaded triangle soup; every 3 points form a triangle. Faces are oriented away from `center`.
    static func flat(_ pts: [SIMD3<Float>], center: SIMD3<Float>) -> SCNGeometry {
        var verts: [SCNVector3] = []
        var norms: [SCNVector3] = []
        var idx: [Int32] = []
        var i = 0
        while i + 2 < pts.count {
            let a = pts[i]
            var b = pts[i + 1]
            var c = pts[i + 2]
            i += 3
            var n = simd_cross(b - a, c - a)
            let len = simd_length(n)
            if len < 1e-7 { continue }
            n /= len
            let centroid = (a + b + c) / 3
            if simd_dot(n, centroid - center) < 0 {
                swap(&b, &c)
                n = -n
            }
            for p in [a, b, c] {
                verts.append(SCNVector3(p.x, p.y, p.z))
                norms.append(SCNVector3(n.x, n.y, n.z))
                idx.append(Int32(verts.count - 1))
            }
        }
        let el = SCNGeometryElement(indices: idx, primitiveType: .triangles)
        return SCNGeometry(sources: [SCNGeometrySource(vertices: verts), SCNGeometrySource(normals: norms)],
                           elements: [el])
    }

    /// Jittered icosahedron: a faceted low-poly rock.
    static func rock(radius: Float, squash: Float, seed: Int) -> SCNGeometry {
        let t: Float = (1 + sqrt(5)) / 2
        var v: [SIMD3<Float>] = [
            SIMD3(-1, t, 0), SIMD3(1, t, 0), SIMD3(-1, -t, 0), SIMD3(1, -t, 0),
            SIMD3(0, -1, t), SIMD3(0, 1, t), SIMD3(0, -1, -t), SIMD3(0, 1, -t),
            SIMD3(t, 0, -1), SIMD3(t, 0, 1), SIMD3(-t, 0, -1), SIMD3(-t, 0, 1),
        ]
        var rng = SeededRNG(seed: UInt64(seed &* 7919 &+ 17))
        for k in 0..<v.count {
            let j = Float.random(in: 0.78...1.14, using: &rng)
            var p = simd_normalize(v[k]) * radius * j
            p.y *= squash
            v[k] = p
        }
        let faces: [(Int, Int, Int)] = [
            (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
            (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
            (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
            (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1),
        ]
        var pts: [SIMD3<Float>] = []
        for f in faces { pts += [v[f.0], v[f.1], v[f.2]] }
        return flat(pts, center: .zero)
    }

    /// Hexagonal crystal with a pointed tip, base at y = 0.
    static func crystal(radius r: Float, height h: Float) -> SCNGeometry {
        let tip = h * 0.35
        var bottom: [SIMD3<Float>] = []
        var top: [SIMD3<Float>] = []
        for i in 0..<6 {
            let a = Float(i) / 6 * 2 * Float.pi
            bottom.append(SIMD3(cos(a) * r, 0, sin(a) * r))
            top.append(SIMD3(cos(a) * r, h, sin(a) * r))
        }
        let apex = SIMD3<Float>(0, h + tip, 0)
        var pts: [SIMD3<Float>] = []
        for i in 0..<6 {
            let j = (i + 1) % 6
            pts += [bottom[i], bottom[j], top[j]]
            pts += [bottom[i], top[j], top[i]]
            pts += [top[i], top[j], apex]
            pts += [bottom[i], bottom[j], SIMD3(0, 0, 0)]
        }
        return flat(pts, center: SIMD3(0, h * 0.5, 0))
    }

    /// Flat arrow lying on the XZ plane, pointing to -Z.
    static func arrow() -> SCNGeometry {
        let pts: [SIMD3<Float>] = [
            SIMD3(0, 0, -0.17), SIMD3(-0.14, 0, -0.01), SIMD3(0.14, 0, -0.01),
            SIMD3(-0.055, 0, -0.01), SIMD3(0.055, 0, -0.01), SIMD3(0.055, 0, 0.12),
            SIMD3(-0.055, 0, -0.01), SIMD3(0.055, 0, 0.12), SIMD3(-0.055, 0, 0.12),
        ]
        return flat(pts, center: SIMD3(0, -1, 0))
    }

    /// Quarter-circle belt surface for corners. Output is -Z; input comes from -X (fromLeft) or +X.
    static func arcBelt(fromLeft: Bool, inner: Float = 0.1, outer: Float = 0.9, segments: Int = 10) -> SCNGeometry {
        let cx: Float = fromLeft ? -0.5 : 0.5
        let cz: Float = -0.5
        var verts: [SCNVector3] = []
        var uvs: [CGPoint] = []
        for i in 0...segments {
            let t = Float(i) / Float(segments)
            let th = t * Float.pi / 2
            let dx = fromLeft ? sin(th) : -sin(th)
            let dz = cos(th)
            let v = CGFloat(1 - t)
            verts.append(SCNVector3(cx + dx * inner, 0, cz + dz * inner))
            uvs.append(CGPoint(x: fromLeft ? 0 : 1, y: v))
            verts.append(SCNVector3(cx + dx * outer, 0, cz + dz * outer))
            uvs.append(CGPoint(x: fromLeft ? 1 : 0, y: v))
        }
        // Make triangles face up
        let p0 = SIMD3<Float>(verts[0].x, 0, verts[0].z)
        let p1 = SIMD3<Float>(verts[1].x, 0, verts[1].z)
        let p3 = SIMD3<Float>(verts[3].x, 0, verts[3].z)
        let up = simd_cross(p1 - p0, p3 - p0).y > 0
        var idx: [Int32] = []
        for i in 0..<segments {
            let a = Int32(2 * i), b = a + 1, c = a + 2, d = a + 3
            if up {
                idx += [a, b, d, a, d, c]
            } else {
                idx += [a, d, b, a, c, d]
            }
        }
        let normals = [SCNVector3](repeating: SCNVector3(0, 1, 0), count: verts.count)
        return SCNGeometry(sources: [SCNGeometrySource(vertices: verts), SCNGeometrySource(normals: normals),
                                     SCNGeometrySource(textureCoordinates: uvs)],
                           elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
    }

    /// Belt surface quad with UVs: v = 0 at the output (-Z) end.
    static func beltQuad(width w: Float, length l: Float) -> SCNGeometry {
        let hw = w / 2, hl = l / 2
        let verts = [SCNVector3(-hw, 0, -hl), SCNVector3(hw, 0, -hl), SCNVector3(-hw, 0, hl), SCNVector3(hw, 0, hl)]
        let normals = [SCNVector3](repeating: SCNVector3(0, 1, 0), count: 4)
        let uvs = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)]
        let idx: [Int32] = [0, 2, 3, 0, 3, 1]
        return SCNGeometry(sources: [SCNGeometrySource(vertices: verts), SCNGeometrySource(normals: normals),
                                     SCNGeometrySource(textureCoordinates: uvs)],
                           elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
    }
}

// MARK: - Model library

enum BeltShape {
    case straight, left, right
}

final class ModelLibrary {
    let beltMaterial: SCNMaterial
    private let beltGeometry: SCNGeometry
    private var buildingTemplates: [BuildingType: SCNNode] = [:]
    private var itemTemplates: [ItemType: SCNNode] = [:]
    private var rockGeos: [Resource: [SCNGeometry]] = [:]
    private var treeTemplates: [SCNNode] = []
    let arrowGeometry: SCNGeometry

    init() {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = Tex.belt
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.mipFilter = .linear
        m.roughness.contents = NSNumber(value: 0.85)
        m.metalness.contents = NSNumber(value: 0.0)
        beltMaterial = m
        let belt = Geo.beltQuad(width: 0.8, length: 1.0)
        belt.materials = [m]
        beltGeometry = belt
        let arrow = Geo.arrow()
        arrow.materials = [M.arrow]
        arrowGeometry = arrow
    }

    // MARK: Buildings

    private var cornerTemplates: [Bool: SCNNode] = [:]

    func conveyor(_ shape: BeltShape) -> SCNNode {
        switch shape {
        case .straight: return building(.conveyor)
        case .left, .right:
            let fromLeft = shape == .left
            if let t = cornerTemplates[fromLeft] { return t.clone() }
            let t = makeCorner(fromLeft: fromLeft)
            cornerTemplates[fromLeft] = t
            return t.clone()
        }
    }

    private func makeCorner(fromLeft: Bool) -> SCNNode {
        let root = SCNNode()
        let sx: Float = fromLeft ? 1 : -1
        root.add(
            Geo.box(0.97, 0.09, 0.97, M.frame).at(-0.015 * sx, 0.045, -0.015),
            Geo.box(0.07, 0.07, 1.0, M.rail, chamfer: 0.015).at(0.43 * sx, 0.125, 0),
            Geo.box(1.0, 0.07, 0.07, M.rail, chamfer: 0.015).at(0, 0.125, 0.43),
            Geo.box(0.09, 0.07, 0.09, M.rail, chamfer: 0.015).at(-0.45 * sx, 0.125, -0.45)
        )
        let arc = Geo.arcBelt(fromLeft: fromLeft)
        arc.materials = [beltMaterial]
        root.addChildNode(SCNNode(geometry: arc).at(0, 0.092, 0))
        return root
    }

    func building(_ t: BuildingType) -> SCNNode {
        if let tpl = buildingTemplates[t] { return tpl.clone() }
        let n: SCNNode
        switch t {
        case .conveyor: n = makeConveyor()
        case .drill: n = makeDrill()
        case .smelter: n = makeSmelter()
        case .assembler: n = makeAssembler()
        case .splitter: n = makeSplitter()
        case .junction: n = makeJunction()
        case .market: n = makeMarket()
        }
        buildingTemplates[t] = n
        return n.clone()
    }

    private func arrowNode(scale: Float = 1) -> SCNNode {
        let a = SCNNode(geometry: arrowGeometry)
        a.scale = SCNVector3(scale, scale, scale)
        return a
    }

    private func makeConveyor() -> SCNNode {
        let root = SCNNode()
        root.add(
            Geo.box(0.94, 0.09, 1.0, M.frame).at(0, 0.045, 0),
            Geo.box(0.07, 0.07, 1.0, M.rail, chamfer: 0.015).at(-0.43, 0.125, 0),
            Geo.box(0.07, 0.07, 1.0, M.rail, chamfer: 0.015).at(0.43, 0.125, 0),
            SCNNode(geometry: beltGeometry).at(0, 0.092, 0)
        )
        return root
    }

    private func makeDrill() -> SCNNode {
        let root = SCNNode()
        root.addChildNode(Geo.box(0.9, 0.1, 0.9, M.steelDark, chamfer: 0.03).at(0, 0.05, 0))
        for (x, z) in [(-0.32, -0.32), (0.32, -0.32), (-0.32, 0.32), (0.32, 0.32)] as [(Float, Float)] {
            root.addChildNode(Geo.box(0.07, 0.8, 0.07, M.yellow, chamfer: 0.012).at(x, 0.5, z))
        }
        root.add(
            Geo.box(0.64, 0.05, 0.05, M.yellow).at(0, 0.48, -0.32),
            Geo.box(0.64, 0.05, 0.05, M.yellow).at(0, 0.48, 0.32),
            Geo.box(0.05, 0.05, 0.64, M.yellow).at(-0.32, 0.48, 0),
            Geo.box(0.05, 0.05, 0.64, M.yellow).at(0.32, 0.48, 0),
            Geo.box(0.8, 0.12, 0.8, M.yellow, chamfer: 0.035).at(0, 0.95, 0),
            Geo.box(0.36, 0.22, 0.36, M.steelDark, chamfer: 0.05).at(0, 1.12, 0),
            Geo.cylinder(0.06, 0.08, M.steel).at(0.1, 1.27, 0.1),
            Geo.sphere(0.05, M.redLight, segments: 10).at(-0.1, 1.27, -0.1).named("glow")
        )
        let spin = SCNNode().named("spin")
        spin.add(
            Geo.cylinder(0.045, 0.62, M.chrome, segments: 12).at(0, 0.6, 0),
            Geo.cone(0.17, 0.0, 0.34, M.chrome, segments: 14).at(0, 0.26, 0),
            Geo.cylinder(0.12, 0.05, M.steel, segments: 14).at(0, 0.45, 0)
        )
        for k in 0..<3 {
            let a = Float(k) * 2 * Float.pi / 3
            let fin = Geo.box(0.025, 0.24, 0.1, M.chrome)
            fin.position = SCNVector3(cos(a) * 0.09, 0.3, sin(a) * 0.09)
            fin.eulerAngles = SCNVector3(0.35, -a, 0)
            spin.addChildNode(fin)
        }
        root.addChildNode(spin)
        root.addChildNode(arrowNode(scale: 0.75).at(0, 0.102, -0.37))
        return root
    }

    private func makeSmelter() -> SCNNode {
        let root = SCNNode()
        root.add(
            Geo.box(0.92, 0.1, 0.92, M.stoneGray, chamfer: 0.03).at(0, 0.05, 0),
            Geo.box(0.84, 0.07, 0.76, M.roof, chamfer: 0.02).at(0, 0.135, 0.06),
            Geo.box(0.8, 0.5, 0.72, M.brick, chamfer: 0.06).at(0, 0.4, 0.06),
            Geo.box(0.86, 0.08, 0.78, M.roof, chamfer: 0.03).at(0, 0.68, 0.06),
            Geo.cylinder(0.1, 0.62, M.stoneGray, segments: 14).at(0.2, 0.98, 0.2),
            Geo.cylinder(0.12, 0.07, M.roof, segments: 14).at(0.2, 1.3, 0.2),
            Geo.box(0.46, 0.32, 0.05, M.roof, chamfer: 0.02).at(0, 0.36, -0.31),
            Geo.box(0.36, 0.22, 0.03, M.furnaceGlow).at(0, 0.34, -0.335).named("glow"),
            SCNNode().at(0.2, 1.34, 0.2).named("smokeAt")
        )
        root.addChildNode(arrowNode(scale: 0.6).at(0, 0.102, -0.39))
        return root
    }

    private func makeAssembler() -> SCNNode {
        let root = SCNNode()
        root.add(
            Geo.box(0.92, 0.1, 0.92, M.steelDark, chamfer: 0.03).at(0, 0.05, 0),
            Geo.box(0.82, 0.4, 0.74, M.blue, chamfer: 0.07).at(0, 0.3, 0.06),
            Geo.box(0.845, 0.06, 0.765, M.cyanGlow, chamfer: 0.03).at(0, 0.36, 0.06).named("glow"),
            Geo.box(0.72, 0.05, 0.64, M.roof, chamfer: 0.02).at(0, 0.525, 0.06),
            Geo.box(0.34, 0.2, 0.03, M.black, chamfer: 0.01).at(0, 0.2, -0.31),
            Geo.cylinder(0.12, 0.05, M.roof, segments: 16).at(0.17, 0.57, -0.1)
        )
        let arm = SCNNode().named("arm")
        arm.position = SCNVector3(-0.16, 0.55, 0.22)
        arm.add(
            Geo.cylinder(0.09, 0.08, M.yellow, segments: 14).at(0, 0.04, 0),
            Geo.sphere(0.055, M.steel, segments: 10).at(0, 0.11, 0),
            Geo.box(0.06, 0.06, 0.3, M.yellow, chamfer: 0.015).at(0, 0.15, -0.13).rot(-0.25, 0, 0),
            Geo.box(0.1, 0.04, 0.06, M.steel).at(0, 0.18, -0.29)
        )
        root.addChildNode(arm)
        root.addChildNode(SCNNode().at(0.17, 0.6, -0.1).named("product"))
        root.addChildNode(arrowNode(scale: 0.6).at(0, 0.102, -0.39))
        return root
    }

    private func makeSplitter() -> SCNNode {
        let root = SCNNode()
        root.add(
            Geo.box(0.92, 0.16, 0.92, M.purple, chamfer: 0.04).at(0, 0.08, 0),
            Geo.box(0.7, 0.02, 0.7, M.roof).at(0, 0.165, 0)
        )
        let forward = arrowNode(scale: 0.8).at(0, 0.178, -0.16)
        let left = arrowNode(scale: 0.8).at(-0.16, 0.178, 0.02)
        left.eulerAngles.y = Float.pi / 2
        let right = arrowNode(scale: 0.8).at(0.16, 0.178, 0.02)
        right.eulerAngles.y = -Float.pi / 2
        root.add(forward, left, right)
        return root
    }

    private func makeJunction() -> SCNNode {
        let root = SCNNode()
        root.add(
            Geo.box(0.92, 0.14, 0.92, M.steelDark, chamfer: 0.03).at(0, 0.07, 0),
            Geo.box(0.34, 0.02, 0.92, M.rubber).at(0, 0.15, 0),
            Geo.box(0.92, 0.02, 0.34, M.rubber).at(0, 0.151, 0)
        )
        for (x, z) in [(-0.33, -0.33), (0.33, -0.33), (-0.33, 0.33), (0.33, 0.33)] as [(Float, Float)] {
            root.addChildNode(Geo.box(0.2, 0.05, 0.2, M.hazard, chamfer: 0.01).at(x, 0.16, z))
        }
        return root
    }

    private func makeMarket() -> SCNNode {
        let root = SCNNode()
        root.add(
            Geo.box(0.94, 0.08, 0.94, M.green, chamfer: 0.03).at(0, 0.04, 0),
            Geo.box(0.78, 0.42, 0.6, M.cream, chamfer: 0.03).at(0, 0.29, 0.1),
            Geo.box(0.86, 0.08, 0.7, M.terracotta, chamfer: 0.03).at(0, 0.54, 0.1),
            Geo.box(0.5, 0.18, 0.02, M.window).at(0, 0.32, -0.205),
            Geo.box(0.82, 0.03, 0.28, M.awning).at(0, 0.45, -0.3).rot(-0.38, 0, 0),
            Geo.box(0.68, 0.12, 0.12, M.wood, chamfer: 0.01).at(0, 0.14, -0.3),
            Geo.box(0.13, 0.13, 0.13, M.woodDark, chamfer: 0.01).at(0.37, 0.145, -0.36),
            Geo.box(0.11, 0.11, 0.11, M.wood, chamfer: 0.01).at(-0.37, 0.135, -0.37),
            Geo.cylinder(0.025, 0.36, M.steel, segments: 8).at(0, 0.76, 0.1)
        )
        let coin = SCNNode().named("coin")
        coin.position = SCNVector3(0, 1.02, 0.1)
        let disc = Geo.cylinder(0.21, 0.05, M.gold, segments: 28)
        disc.eulerAngles.x = Float.pi / 2
        let inner = Geo.cylinder(0.15, 0.06, M.goldDark, segments: 24)
        inner.eulerAngles.x = Float.pi / 2
        coin.add(disc, inner)
        root.addChildNode(coin)
        return root
    }

    // MARK: Items

    func item(_ t: ItemType) -> SCNNode {
        if let tpl = itemTemplates[t] { return tpl.clone() }
        let n = makeItem(t).flattenedClone()
        n.castsShadow = true
        itemTemplates[t] = n
        return n.clone()
    }

    private func makeItem(_ t: ItemType) -> SCNNode {
        let root = SCNNode()
        let c = MaterialCache.shared
        let mat = c.pbr(t.hex, rough: 0.5, metal: 0.2)
        switch t {
        case .ironOre, .copperOre, .stone, .coal:
            let seed = (ItemType.allCases.firstIndex(of: t) ?? 0) + 3
            let r = Geo.node(Geo.rock(radius: 0.11, squash: 0.8, seed: seed), c.pbr(t.hex, rough: 0.8, metal: 0.1))
            root.addChildNode(r.at(0, 0.075, 0))
        case .goldOre:
            root.addChildNode(Geo.node(Geo.rock(radius: 0.105, squash: 0.8, seed: 5), c.pbr(0x5A4A3A, rough: 0.9)).at(0, 0.07, 0))
            root.addChildNode(Geo.node(Geo.rock(radius: 0.06, squash: 0.9, seed: 9), M.gold).at(0.05, 0.11, -0.02))
        case .quartz:
            let m = c.pbr(t.hex, rough: 0.15, metal: 0.0, emission: 0xF0C8F0, glow: 0.25)
            root.addChildNode(Geo.node(Geo.crystal(radius: 0.045, height: 0.15), m).rot(0.2, 0, 0.15))
            root.addChildNode(Geo.node(Geo.crystal(radius: 0.035, height: 0.11), m).at(0.06, 0, 0.03).rot(0, 0, -0.5))
        case .ironPlate, .copperPlate:
            root.addChildNode(Geo.box(0.24, 0.05, 0.24, c.pbr(t.hex, rough: 0.3, metal: 0.85), chamfer: 0.012).at(0, 0.025, 0))
        case .brick:
            root.addChildNode(Geo.box(0.24, 0.1, 0.13, c.pbr(t.hex, rough: 0.9), chamfer: 0.01).at(0, 0.05, 0))
        case .glass:
            root.addChildNode(Geo.box(0.22, 0.05, 0.22, c.pbr(t.hex, rough: 0.05, metal: 0.1, alpha: 0.75), chamfer: 0.01).at(0, 0.025, 0))
        case .goldBar:
            root.addChildNode(Geo.box(0.22, 0.08, 0.11, M.gold, chamfer: 0.02).at(0, 0.04, 0))
        case .steel:
            let s = c.pbr(t.hex, rough: 0.35, metal: 0.9)
            root.add(
                Geo.box(0.26, 0.025, 0.11, s).at(0, 0.0125, 0),
                Geo.box(0.26, 0.06, 0.03, s).at(0, 0.055, 0),
                Geo.box(0.26, 0.025, 0.11, s).at(0, 0.0975, 0)
            )
        case .gear:
            let g = c.pbr(t.hex, rough: 0.3, metal: 0.9)
            root.addChildNode(Geo.tube(0.035, 0.095, 0.05, g).at(0, 0.025, 0))
            for k in 0..<8 {
                let a = Float(k) / 8 * 2 * Float.pi
                let tooth = Geo.box(0.04, 0.05, 0.04, g)
                tooth.position = SCNVector3(cos(a) * 0.105, 0.025, sin(a) * 0.105)
                tooth.eulerAngles.y = -a
                root.addChildNode(tooth)
            }
        case .wire:
            let copper = c.pbr(t.hex, rough: 0.3, metal: 0.9)
            root.add(
                Geo.cylinder(0.09, 0.018, M.woodDark, segments: 18).at(0, 0.009, 0),
                Geo.cylinder(0.072, 0.09, copper, segments: 18).at(0, 0.063, 0),
                Geo.cylinder(0.09, 0.018, M.woodDark, segments: 18).at(0, 0.117, 0),
                Geo.cylinder(0.025, 0.13, M.wood, segments: 10).at(0, 0.065, 0)
            )
        case .circuit:
            root.add(
                Geo.box(0.24, 0.025, 0.18, mat, chamfer: 0.005).at(0, 0.0125, 0),
                Geo.box(0.09, 0.03, 0.09, M.black, chamfer: 0.005).at(0, 0.04, 0),
                Geo.box(0.04, 0.012, 0.04, M.gold).at(0.08, 0.03, 0.05),
                Geo.box(0.04, 0.012, 0.04, M.gold).at(-0.08, 0.03, -0.05)
            )
        case .frame:
            let m = c.pbr(t.hex, rough: 0.4, metal: 0.6)
            let s: Float = 0.1, th: CGFloat = 0.03, len: CGFloat = 0.2
            for a in [-s, s] {
                for b in [-s, s] {
                    root.addChildNode(Geo.box(len, th, th, m).at(0, 0.1 + a, b))
                    root.addChildNode(Geo.box(th, len, th, m).at(a, 0.1, b))
                    root.addChildNode(Geo.box(th, th, len, m).at(a, 0.1 + b, 0))
                }
            }
        case .motor:
            let body = Geo.cylinder(0.085, 0.18, mat, segments: 16)
            body.eulerAngles.z = Float.pi / 2
            let cap1 = Geo.cylinder(0.09, 0.025, M.steelDark, segments: 16)
            cap1.eulerAngles.z = Float.pi / 2
            let cap2 = Geo.cylinder(0.09, 0.025, M.steelDark, segments: 16)
            cap2.eulerAngles.z = Float.pi / 2
            let shaft = Geo.cylinder(0.018, 0.08, M.chrome, segments: 8)
            shaft.eulerAngles.z = Float.pi / 2
            root.add(body.at(0, 0.09, 0), cap1.at(-0.09, 0.09, 0), cap2.at(0.09, 0.09, 0), shaft.at(0.14, 0.09, 0))
        case .processor:
            root.add(
                Geo.box(0.2, 0.03, 0.2, mat, chamfer: 0.005).at(0, 0.015, 0),
                Geo.box(0.12, 0.012, 0.12, M.gold).at(0, 0.036, 0),
                Geo.box(0.22, 0.008, 0.02, M.gold).at(0, 0.008, 0.06),
                Geo.box(0.22, 0.008, 0.02, M.gold).at(0, 0.008, -0.06)
            )
        case .robot:
            let eye = c.pbr(0x5FD0FF, rough: 0.2, emission: 0x5FD0FF, glow: 1.5)
            root.add(
                Geo.box(0.05, 0.08, 0.05, M.steelDark).at(-0.045, 0.04, 0),
                Geo.box(0.05, 0.08, 0.05, M.steelDark).at(0.045, 0.04, 0),
                Geo.box(0.17, 0.14, 0.12, M.white, chamfer: 0.025).at(0, 0.15, 0),
                Geo.box(0.04, 0.1, 0.04, M.steel).at(-0.11, 0.15, 0),
                Geo.box(0.04, 0.1, 0.04, M.steel).at(0.11, 0.15, 0),
                Geo.box(0.13, 0.1, 0.11, M.white, chamfer: 0.03).at(0, 0.28, 0),
                Geo.sphere(0.018, eye, segments: 8).at(-0.03, 0.29, -0.056),
                Geo.sphere(0.018, eye, segments: 8).at(0.03, 0.29, -0.056),
                Geo.cylinder(0.006, 0.06, M.steel, segments: 6).at(0, 0.36, 0),
                Geo.sphere(0.016, M.furnaceGlow, segments: 8).at(0, 0.395, 0)
            )
        }
        return root
    }

    // MARK: Decorations

    func rock(_ r: Resource, variant: Int) -> SCNGeometry {
        if let list = rockGeos[r] { return list[variant % list.count] }
        var list: [SCNGeometry] = []
        let mat: SCNMaterial
        switch r {
        case .gold: mat = MaterialCache.shared.pbr(r.rockHex, rough: 0.3, metal: 0.9)
        case .quartz: mat = MaterialCache.shared.pbr(r.rockHex, rough: 0.15, emission: 0xF0C0F0, glow: 0.3)
        case .coal: mat = MaterialCache.shared.pbr(r.rockHex, rough: 0.5, metal: 0.3)
        default: mat = MaterialCache.shared.pbr(r.rockHex, rough: 0.85, metal: r == .iron ? 0.35 : 0.1)
        }
        for k in 0..<4 {
            let g: SCNGeometry
            if r == .quartz {
                g = Geo.crystal(radius: 0.06 + Float(k) * 0.01, height: 0.22 + Float(k) * 0.05)
            } else {
                g = Geo.rock(radius: 0.15, squash: 0.65, seed: r.rawValue * 31 + k)
            }
            g.materials = [mat]
            list.append(g)
        }
        rockGeos[r] = list
        return list[variant % list.count]
    }

    func tree(variant: Int) -> SCNNode {
        if treeTemplates.isEmpty {
            for k in 0..<4 {
                let t = SCNNode()
                t.addChildNode(Geo.cylinder(0.05, 0.3, M.trunk, segments: 6).at(0, 0.15, 0))
                if k % 2 == 0 {
                    let leaf = k == 0 ? M.leaves2 : M.leaves
                    t.addChildNode(Geo.cone(0, 0.3, 0.46, leaf, segments: 7).at(0, 0.45, 0))
                    t.addChildNode(Geo.cone(0, 0.22, 0.36, leaf, segments: 7).at(0, 0.7, 0))
                } else {
                    let leaf = k == 1 ? M.leaves3 : M.leaves
                    t.addChildNode(Geo.node(Geo.rock(radius: 0.27, squash: 1.0, seed: 100 + k), leaf).at(0, 0.52, 0))
                }
                treeTemplates.append(t)
            }
        }
        return treeTemplates[variant % treeTemplates.count].clone()
    }
}
