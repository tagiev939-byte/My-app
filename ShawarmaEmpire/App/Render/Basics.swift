import SceneKit
import UIKit
import simd

// MARK: - Random helpers

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

func hash01(_ a: Int, _ b: Int, _ c: Int = 0) -> Float {
    var h = UInt64(bitPattern: Int64(a &* 73856093 ^ b &* 19349663 ^ c &* 83492791))
    h ^= h >> 33
    h = h &* 0xff51afd7ed558ccd
    h ^= h >> 33
    h = h &* 0xc4ceb9fe1a85ec53
    h ^= h >> 33
    return Float(h % 100_000) / 100_000
}

// MARK: - Materials

final class MaterialCache {
    static let shared = MaterialCache()
    private var cache: [String: SCNMaterial] = [:]

    func pbr(_ hex: UInt32, rough: CGFloat = 0.65, metal: CGFloat = 0, emission: UInt32? = nil,
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

    func textured(_ key: String, _ image: UIImage, rough: CGFloat = 0.8, metal: CGFloat = 0,
                  emission: UIImage? = nil, repeatS: Float = 1, repeatT: Float = 1) -> SCNMaterial {
        if let m = cache[key] { return m }
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = image
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.mipFilter = .linear
        m.diffuse.maxAnisotropy = 4
        if repeatS != 1 || repeatT != 1 {
            m.diffuse.contentsTransform = SCNMatrix4MakeScale(repeatS, repeatT, 1)
        }
        if let emission {
            m.emission.contents = emission
            m.emission.wrapS = .repeat
            m.emission.wrapT = .repeat
            m.emission.contentsTransform = m.diffuse.contentsTransform
            m.emission.intensity = 0
        }
        m.roughness.contents = NSNumber(value: Double(rough))
        m.metalness.contents = NSNumber(value: Double(metal))
        cache[key] = m
        return m
    }

    /// Unlit material (for signs, bubbles, glowing things).
    func flat(_ key: String, _ contents: Any, alpha: Bool = false) -> SCNMaterial {
        if let m = cache[key] { return m }
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = contents
        if alpha { m.blendMode = .alpha }
        cache[key] = m
        return m
    }
}

/// Shared palette. Night-dependent materials are adjusted every frame by the renderer.
enum M {
    static var c: MaterialCache { MaterialCache.shared }
    static var steel: SCNMaterial { c.pbr(0xB8C0C8, rough: 0.35, metal: 0.75) }
    static var steelDark: SCNMaterial { c.pbr(0x5A626C, rough: 0.45, metal: 0.6) }
    static var chrome: SCNMaterial { c.pbr(0xE0E5EA, rough: 0.2, metal: 0.95) }
    static var black: SCNMaterial { c.pbr(0x1E2024, rough: 0.5, metal: 0.1) }
    static var white: SCNMaterial { c.pbr(0xF7F7F5, rough: 0.6) }
    static var wood: SCNMaterial { c.pbr(0xA0703F, rough: 0.85) }
    static var woodDark: SCNMaterial { c.pbr(0x6B4428, rough: 0.85) }
    static var concrete: SCNMaterial { c.pbr(0xB9B4AA, rough: 0.95) }
    static var asphalt: SCNMaterial { c.pbr(0x3C3F44, rough: 0.95) }
    static var grass: SCNMaterial { c.pbr(0x7DB356, rough: 0.95) }
    static var leaves: SCNMaterial { c.pbr(0x4E9A3E, rough: 0.85) }
    static var leaves2: SCNMaterial { c.pbr(0x6DAA3E, rough: 0.85) }
    static var trunk: SCNMaterial { c.pbr(0x7A5133, rough: 0.95) }
    static var glass: SCNMaterial { c.pbr(0xBFE3F5, rough: 0.05, metal: 0.1, alpha: 0.35) }
    static var gold: SCNMaterial { c.pbr(0xF5C542, rough: 0.28, metal: 0.95) }
    static var red: SCNMaterial { c.pbr(0xD32F2F, rough: 0.5) }
    static var screen: SCNMaterial { c.pbr(0x0D2B3A, rough: 0.2, emission: 0x41C7FF, glow: 0.8) }

    // Night lights (emission intensity animated by the renderer)
    static let bulb: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(hex: 0xFFF4D6)
        m.emission.contents = UIColor(hex: 0xFFD68A)
        m.emission.intensity = 0.3
        m.roughness.contents = NSNumber(value: 0.3)
        return m
    }()

    static let headlight: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(hex: 0xFFFDE7)
        m.emission.contents = UIColor(hex: 0xFFF3C4)
        m.emission.intensity = 0.3
        return m
    }()

    static let taillight: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(hex: 0xB71C1C)
        m.emission.contents = UIColor(hex: 0xFF3B30)
        m.emission.intensity = 0.3
        return m
    }()

    static let halo: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = Tex.softCircle
        m.multiply.contents = UIColor(hex: 0xFFC56E)
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.transparency = 0
        return m
    }()
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
    func scaled(_ s: Float) -> SCNNode {
        scale = SCNVector3(s, s, s)
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

    /// Merge all direct geometry children into one node (fewer draw calls).
    func flattenedLeaves() -> SCNNode {
        let flat = flattenedClone()
        flat.castsShadow = castsShadow
        return flat
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

    static func tube(_ inner: CGFloat, _ outer: CGFloat, _ h: CGFloat, _ m: SCNMaterial, segments: Int = 24) -> SCNNode {
        let g = SCNTube(innerRadius: inner, outerRadius: outer, height: h)
        g.radialSegmentCount = segments
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

    static func plane(_ w: CGFloat, _ h: CGFloat, _ m: SCNMaterial) -> SCNNode {
        let g = SCNPlane(width: w, height: h)
        g.materials = [m]
        return SCNNode(geometry: g)
    }

    /// Plane lying flat (facing up).
    static func floor(_ w: CGFloat, _ l: CGFloat, _ m: SCNMaterial) -> SCNNode {
        let n = plane(w, l, m)
        n.eulerAngles.x = -Float.pi / 2
        return n
    }

    static func node(_ g: SCNGeometry, _ m: SCNMaterial) -> SCNNode {
        g.materials = [m]
        return SCNNode(geometry: g)
    }

    /// Flat-shaded triangle soup (every 3 points), faces oriented away from `center`.
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
            if simd_dot(n, (a + b + c) / 3 - center) < 0 {
                swap(&b, &c)
                n = -n
            }
            for p in [a, b, c] {
                verts.append(SCNVector3(p.x, p.y, p.z))
                norms.append(SCNVector3(n.x, n.y, n.z))
                idx.append(Int32(verts.count - 1))
            }
        }
        let uvs = [CGPoint](repeating: CGPoint(x: 0.5, y: 0.5), count: verts.count)
        return SCNGeometry(sources: [SCNGeometrySource(vertices: verts), SCNGeometrySource(normals: norms),
                                     SCNGeometrySource(textureCoordinates: uvs)],
                           elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
    }

    /// Jittered icosahedron: low-poly rock / bush / tree crown.
    static func blob(radius: Float, squash: Float, seed: Int) -> SCNGeometry {
        let t: Float = (1 + sqrt(5)) / 2
        var v: [SIMD3<Float>] = [
            SIMD3(-1, t, 0), SIMD3(1, t, 0), SIMD3(-1, -t, 0), SIMD3(1, -t, 0),
            SIMD3(0, -1, t), SIMD3(0, 1, t), SIMD3(0, -1, -t), SIMD3(0, 1, -t),
            SIMD3(t, 0, -1), SIMD3(t, 0, 1), SIMD3(-t, 0, -1), SIMD3(-t, 0, 1),
        ]
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(seed &* 7919 &+ 17)))
        for k in 0..<v.count {
            var p = simd_normalize(v[k]) * radius * Float.random(in: 0.82...1.12, using: &rng)
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

    /// Triangular prism (roof gable / pediment), along X, peak up.
    static func gable(width w: Float, height h: Float, depth d: Float) -> SCNGeometry {
        let hw = w / 2, hd = d / 2
        let a0 = SIMD3<Float>(-hw, 0, -hd), b0 = SIMD3<Float>(hw, 0, -hd), c0 = SIMD3<Float>(0, h, -hd)
        let a1 = SIMD3<Float>(-hw, 0, hd), b1 = SIMD3<Float>(hw, 0, hd), c1 = SIMD3<Float>(0, h, hd)
        let pts: [SIMD3<Float>] = [a0, b0, c0, a1, b1, c1,
                                   a0, c0, c1, a0, c1, a1,
                                   b0, b1, c1, b0, c1, c0,
                                   a0, a1, b1, a0, b1, b0]
        return flat(pts, center: SIMD3(0, h / 3, 0))
    }
}

/// Merges a set of nodes (with their hierarchy) into one optimized node.
/// Plain colored materials are baked into vertex colors, so a whole model usually costs 1–3 draw calls.
func merged(_ nodes: [SCNNode], shadows: Bool = true) -> SCNNode {
    let holder = SCNNode()
    for n in nodes { holder.addChildNode(n) }
    // flattenedClone only merges geometry that sits on direct children, so flatten nested groups first.
    for child in holder.childNodes where !child.childNodes.isEmpty {
        let f = child.flattenedClone()
        child.removeFromParentNode()
        holder.addChildNode(f)
    }
    let flat = holder.flattenedClone()
    if let g = flat.geometry, let baked = Bake.vertexColors(g) {
        flat.geometry = baked
    }
    flat.castsShadow = shadows
    return flat
}

/// Bakes solid-color PBR materials into a per-vertex color source and merges their elements.
enum Bake {
    private static var materials: [String: SCNMaterial] = [:]

    private static func number(_ p: SCNMaterialProperty, _ fallback: CGFloat) -> CGFloat {
        if let n = p.contents as? NSNumber { return CGFloat(n.doubleValue) }
        return fallback
    }

    private static func isBlack(_ any: Any?) -> Bool {
        guard let any else { return true }
        guard let c = any as? UIColor else { return false }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r + g + b < 0.001
    }

    private static func isWhite(_ any: Any?) -> Bool {
        guard let any else { return true }
        guard let c = any as? UIColor else { return false }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r > 0.999 && g > 0.999 && b > 0.999
    }

    private static func linear(_ v: CGFloat) -> Float {
        let x = Float(max(0, min(1, v)))
        return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
    }

    /// Linear RGBA color of a material that can be baked, or nil.
    private static func bakeable(_ m: SCNMaterial) -> SIMD4<Float>? {
        guard m.lightingModel == .physicallyBased, m.transparency > 0.999, m.blendMode == .alpha,
              !m.isDoubleSided, let c = m.diffuse.contents as? UIColor,
              isBlack(m.emission.contents) || m.emission.intensity == 0,
              m.normal.contents == nil, isWhite(m.multiply.contents) else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        guard a > 0.999 else { return nil }
        return SIMD4(linear(r), linear(g), linear(b), 1)
    }

    private static func material(rough: CGFloat, metal: CGFloat) -> SCNMaterial {
        let key = String(format: "%.2f|%.2f", rough, metal)
        if let m = materials[key] { return m }
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor.white
        m.roughness.contents = NSNumber(value: Double(rough))
        m.metalness.contents = NSNumber(value: Double(metal))
        materials[key] = m
        return m
    }

    private static func indices(_ e: SCNGeometryElement) -> [UInt32]? {
        guard e.primitiveType == .triangles else { return nil }
        let count = e.primitiveCount * 3
        let bpi = e.bytesPerIndex
        guard bpi == 2 || bpi == 4, e.data.count >= count * bpi else { return nil }
        var out = [UInt32](repeating: 0, count: count)
        e.data.withUnsafeBytes { raw in
            if bpi == 2 {
                for k in 0..<count { out[k] = UInt32(raw.load(fromByteOffset: k * 2, as: UInt16.self)) }
            } else {
                for k in 0..<count { out[k] = raw.load(fromByteOffset: k * 4, as: UInt32.self) }
            }
        }
        return out
    }

    static func vertexColors(_ g: SCNGeometry) -> SCNGeometry? {
        guard let vsrc = g.sources(for: .vertex).first, g.sources(for: .color).isEmpty else { return nil }
        let n = vsrc.vectorCount
        let mats = g.materials
        guard n > 0, !mats.isEmpty, g.elementCount > 0 else { return nil }
        var colors = [SIMD4<Float>](repeating: SIMD4(1, 1, 1, 1), count: n)
        var groups: [String: (mat: SCNMaterial, idx: [UInt32])] = [:]
        var order: [String] = []
        var keptElements: [SCNGeometryElement] = []
        var keptMaterials: [SCNMaterial] = []
        var bakedAny = false
        for i in 0..<g.elementCount {
            let e = g.element(at: i)
            let m = mats[i % mats.count]
            if let col = bakeable(m), let idx = indices(e), idx.allSatisfy({ Int($0) < n }) {
                for v in idx { colors[Int(v)] = col }
                let rough = number(m.roughness, 0.5), metal = number(m.metalness, 0)
                let key = String(format: "%.2f|%.2f", rough, metal)
                if groups[key] == nil {
                    groups[key] = (material(rough: rough, metal: metal), [])
                    order.append(key)
                }
                groups[key]!.idx += idx
                bakedAny = true
            } else {
                keptElements.append(e)
                keptMaterials.append(m)
            }
        }
        guard bakedAny else { return nil }
        let data = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let csrc = SCNGeometrySource(data: data, semantic: .color, vectorCount: n, usesFloatComponents: true,
                                     componentsPerVector: 4, bytesPerComponent: 4, dataOffset: 0, dataStride: 16)
        var elements: [SCNGeometryElement] = []
        var materials: [SCNMaterial] = []
        for key in order {
            guard let grp = groups[key] else { continue }
            elements.append(SCNGeometryElement(indices: grp.idx, primitiveType: .triangles))
            materials.append(grp.mat)
        }
        elements += keptElements
        materials += keptMaterials
        let out = SCNGeometry(sources: g.sources + [csrc], elements: elements)
        out.materials = materials
        return out
    }
}
