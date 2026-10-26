import SceneKit
import UIKit
import simd

/// Material analysis for vertex-color baking.
enum Bake {
    private static var materials: [String: SCNMaterial] = [:]
    /// QA counters.
    static var stats: [String: Int] = [:]

    static func count(_ k: String) { stats[k, default: 0] += 1 }

    static func number(_ p: SCNMaterialProperty, _ fallback: CGFloat) -> CGFloat {
        if let n = p.contents as? NSNumber { return CGFloat(n.doubleValue) }
        return fallback
    }

    private static func rgba(_ any: Any?) -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
        guard let c = any as? UIColor else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    private static func isBlack(_ any: Any?) -> Bool {
        guard let any else { return true }
        guard let c = rgba(any) else { return false }
        return c.0 + c.1 + c.2 < 0.001
    }

    private static func isWhite(_ any: Any?) -> Bool {
        guard let any else { return true }
        guard let c = rgba(any) else { return false }
        return c.0 > 0.999 && c.1 > 0.999 && c.2 > 0.999
    }

    private static func linear(_ v: CGFloat) -> Float {
        let x = Float(max(0, min(1, v)))
        return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
    }

    static func isBakeMaterial(_ m: SCNMaterial) -> Bool { m.name?.hasPrefix("bake:") == true }

    /// Linear RGBA color of a material that can be baked, or nil.
    static func bakeable(_ m: SCNMaterial) -> SIMD4<Float>? {
        guard m.lightingModel == .physicallyBased, m.transparency > 0.999, m.blendMode == .alpha,
              !m.isDoubleSided, let c = rgba(m.diffuse.contents), c.3 > 0.999,
              isBlack(m.emission.contents) || m.emission.intensity == 0,
              m.normal.contents == nil || isWhite(m.normal.contents),
              isWhite(m.multiply.contents) else { return nil }
        return SIMD4(linear(c.0), linear(c.1), linear(c.2), 1)
    }

    /// Shared white material for baked meshes; few roughness/metalness buckets keep draw calls low.
    static func bucket(for m: SCNMaterial) -> (key: String, material: SCNMaterial) {
        let r0 = number(m.roughness, 0.5), m0 = number(m.metalness, 0)
        let rough: CGFloat = r0 < 0.45 ? 0.3 : 0.75
        let metal: CGFloat = m0 < 0.35 ? 0 : 0.8
        let key = String(format: "%.2f|%.2f", rough, metal)
        if let mat = materials[key] { return (key, mat) }
        let mat = SCNMaterial()
        mat.name = "bake:" + key
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor.white
        mat.roughness.contents = NSNumber(value: Double(rough))
        mat.metalness.contents = NSNumber(value: Double(metal))
        materials[key] = mat
        return (key, mat)
    }
}

/// One piece of mesh in local space using a single material slot.
struct MeshPart {
    var p: [SIMD3<Float>] = []
    var n: [SIMD3<Float>] = []
    var t: [SIMD2<Float>] = []
    var c: [SIMD4<Float>]? = nil
    var i: [UInt32] = []

    mutating func vertex(_ pos: SIMD3<Float>, _ nor: SIMD3<Float>, _ uv: SIMD2<Float>) -> UInt32 {
        p.append(pos)
        n.append(nor)
        t.append(uv)
        return UInt32(p.count - 1)
    }

    /// Adds a triangle, flipping it if needed so it faces along its vertex normals (counter-clockwise front faces).
    mutating func tri(_ a: UInt32, _ b: UInt32, _ c: UInt32) {
        let pa = p[Int(a)], pb = p[Int(b)], pc = p[Int(c)]
        let fn = simd_cross(pb - pa, pc - pa)
        let vn = n[Int(a)] + n[Int(b)] + n[Int(c)]
        if simd_dot(fn, vn) < 0 { i += [a, c, b] } else { i += [a, b, c] }
    }

    mutating func quad(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32) {
        tri(a, b, c)
        tri(a, c, d)
    }
}

/// Generates meshes for SceneKit's parametric primitives with SceneKit-like texture mapping.
enum Prim {
    /// Six faces in SceneKit material order: front, right, back, left, top, bottom.
    static func box(_ w: Float, _ h: Float, _ l: Float, chamfer r0: Float) -> [MeshPart] {
        let half = SIMD3<Float>(w / 2, h / 2, l / 2)
        let r = max(0, min(r0, min(half.x, min(half.y, half.z)) * 0.999))
        // (normal, U axis (left→right), V axis (top→bottom))
        let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = [
            (SIMD3(0, 0, 1), SIMD3(1, 0, 0), SIMD3(0, -1, 0)),
            (SIMD3(1, 0, 0), SIMD3(0, 0, -1), SIMD3(0, -1, 0)),
            (SIMD3(0, 0, -1), SIMD3(-1, 0, 0), SIMD3(0, -1, 0)),
            (SIMD3(-1, 0, 0), SIMD3(0, 0, 1), SIMD3(0, -1, 0)),
            (SIMD3(0, 1, 0), SIMD3(1, 0, 0), SIMD3(0, 0, 1)),
            (SIMD3(0, -1, 0), SIMD3(1, 0, 0), SIMD3(0, 0, -1)),
        ]
        let inner = half - SIMD3(repeating: r)
        var parts: [MeshPart] = []
        for (nrm, ua, va) in faces {
            var part = MeshPart()
            let hu = simd_dot(simd_abs(ua), half), hv = simd_dot(simd_abs(va), half), hn = simd_dot(simd_abs(nrm), half)
            func lines(_ hh: Float) -> [Float] {
                if r <= 0.0001 { return [-hh, hh] }
                return [-hh, -hh + r, hh - r, hh]
            }
            let us = lines(hu), vs = lines(hv)
            var idx: [[UInt32]] = []
            for v in vs {
                var row: [UInt32] = []
                for u in us {
                    var pos = nrm * hn + ua * u + va * v
                    var nn = nrm
                    if r > 0.0001 {
                        let q = simd_clamp(pos, -inner, inner)
                        let d = pos - q
                        let len = simd_length(d)
                        if len > 1e-6 {
                            nn = d / len
                            pos = q + nn * r
                        }
                    }
                    let uv = SIMD2<Float>((u + hu) / (2 * hu), (v + hv) / (2 * hv))
                    row.append(part.vertex(pos, nn, uv))
                }
                idx.append(row)
            }
            for a in 0..<(vs.count - 1) {
                for b in 0..<(us.count - 1) {
                    part.quad(idx[a][b], idx[a][b + 1], idx[a + 1][b + 1], idx[a + 1][b])
                }
            }
            parts.append(part)
        }
        return parts
    }

    static func sphere(_ r: Float, segments s: Int) -> [MeshPart] {
        var part = MeshPart()
        let lon = max(6, s), lat = max(4, s / 2 + 1)
        var rows: [[UInt32]] = []
        for a in 0...lat {
            let v = Float(a) / Float(lat)
            let phi = v * Float.pi
            var row: [UInt32] = []
            for b in 0...lon {
                let u = Float(b) / Float(lon)
                let th = u * 2 * Float.pi
                let nn = SIMD3<Float>(sin(phi) * sin(th), cos(phi), sin(phi) * cos(th))
                row.append(part.vertex(nn * r, nn, SIMD2(u, v)))
            }
            rows.append(row)
        }
        for a in 0..<lat {
            for b in 0..<lon {
                let p0 = rows[a][b], p1 = rows[a][b + 1], p2 = rows[a + 1][b + 1], p3 = rows[a + 1][b]
                if a != 0 { part.tri(p0, p1, p2) }
                if a != lat - 1 { part.tri(p0, p2, p3) }
            }
        }
        return [part]
    }

    /// Side, top cap, bottom cap (SceneKit order). Radii may be zero (cone tip).
    static func frustum(top rt: Float, bottom rb: Float, height h: Float, segments s: Int) -> [MeshPart] {
        let seg = max(3, s)
        var side = MeshPart()
        let slope = (rb - rt) / max(h, 1e-5)
        var topRow: [UInt32] = [], botRow: [UInt32] = []
        for k in 0...seg {
            let u = Float(k) / Float(seg)
            let th = u * 2 * Float.pi
            let dir = SIMD3<Float>(sin(th), 0, cos(th))
            let nn = simd_normalize(SIMD3(dir.x, slope, dir.z))
            topRow.append(side.vertex(dir * rt + SIMD3(0, h / 2, 0), nn, SIMD2(u, 0)))
            botRow.append(side.vertex(dir * rb - SIMD3(0, h / 2, 0), nn, SIMD2(u, 1)))
        }
        for k in 0..<seg {
            if rt > 0.0001 { side.tri(topRow[k], botRow[k], topRow[k + 1]) }
            if rb > 0.0001 { side.tri(topRow[k + 1], botRow[k], botRow[k + 1]) }
        }
        func cap(_ radius: Float, _ y: Float, _ ny: Float) -> MeshPart {
            var c = MeshPart()
            guard radius > 0.0001 else { return c }
            let nn = SIMD3<Float>(0, ny, 0)
            let center = c.vertex(SIMD3(0, y, 0), nn, SIMD2(0.5, 0.5))
            var ring: [UInt32] = []
            for k in 0...seg {
                let th = Float(k) / Float(seg) * 2 * Float.pi
                ring.append(c.vertex(SIMD3(sin(th) * radius, y, cos(th) * radius), nn, SIMD2(0.5 + sin(th) * 0.5, 0.5 + cos(th) * 0.5)))
            }
            for k in 0..<seg { c.tri(center, ring[k], ring[k + 1]) }
            return c
        }
        return [side, cap(rt, h / 2, 1), cap(rb, -h / 2, -1)]
    }

    static func tube(inner ri: Float, outer ro: Float, height h: Float, segments s: Int) -> [MeshPart] {
        let seg = max(3, s)
        var outer = MeshPart(), inner = MeshPart(), top = MeshPart(), bottom = MeshPart()
        var ot: [UInt32] = [], ob: [UInt32] = [], it: [UInt32] = [], ib: [UInt32] = []
        var tt: [UInt32] = [], tb: [UInt32] = [], bt: [UInt32] = [], bb: [UInt32] = []
        for k in 0...seg {
            let u = Float(k) / Float(seg)
            let th = u * 2 * Float.pi
            let dir = SIMD3<Float>(sin(th), 0, cos(th))
            ot.append(outer.vertex(dir * ro + SIMD3(0, h / 2, 0), dir, SIMD2(u, 0)))
            ob.append(outer.vertex(dir * ro - SIMD3(0, h / 2, 0), dir, SIMD2(u, 1)))
            it.append(inner.vertex(dir * ri + SIMD3(0, h / 2, 0), -dir, SIMD2(u, 0)))
            ib.append(inner.vertex(dir * ri - SIMD3(0, h / 2, 0), -dir, SIMD2(u, 1)))
            tt.append(top.vertex(dir * ro + SIMD3(0, h / 2, 0), SIMD3(0, 1, 0), SIMD2(u, 0)))
            tb.append(top.vertex(dir * ri + SIMD3(0, h / 2, 0), SIMD3(0, 1, 0), SIMD2(u, 1)))
            bt.append(bottom.vertex(dir * ro - SIMD3(0, h / 2, 0), SIMD3(0, -1, 0), SIMD2(u, 0)))
            bb.append(bottom.vertex(dir * ri - SIMD3(0, h / 2, 0), SIMD3(0, -1, 0), SIMD2(u, 1)))
        }
        for k in 0..<seg {
            outer.quad(ot[k], ob[k], ob[k + 1], ot[k + 1])
            inner.quad(it[k], ib[k], ib[k + 1], it[k + 1])
            top.quad(tt[k], tb[k], tb[k + 1], tt[k + 1])
            bottom.quad(bt[k], bb[k], bb[k + 1], bt[k + 1])
        }
        return [outer, inner, top, bottom]
    }

    static func torus(ring R: Float, pipe r: Float, ringSegments rs: Int, pipeSegments ps: Int) -> [MeshPart] {
        var part = MeshPart()
        var rows: [[UInt32]] = []
        for a in 0...rs {
            let u = Float(a) / Float(rs)
            let th = u * 2 * Float.pi
            let dir = SIMD3<Float>(sin(th), 0, cos(th))
            var row: [UInt32] = []
            for b in 0...ps {
                let v = Float(b) / Float(ps)
                let ph = v * 2 * Float.pi
                let nn = dir * cos(ph) + SIMD3(0, sin(ph), 0)
                row.append(part.vertex(dir * R + nn * r, nn, SIMD2(u, v)))
            }
            rows.append(row)
        }
        for a in 0..<rs {
            for b in 0..<ps { part.quad(rows[a][b], rows[a + 1][b], rows[a + 1][b + 1], rows[a][b + 1]) }
        }
        return [part]
    }

    static func plane(_ w: Float, _ h: Float) -> [MeshPart] {
        var part = MeshPart()
        let nn = SIMD3<Float>(0, 0, 1)
        let a = part.vertex(SIMD3(-w / 2, h / 2, 0), nn, SIMD2(0, 0))
        let b = part.vertex(SIMD3(w / 2, h / 2, 0), nn, SIMD2(1, 0))
        let c = part.vertex(SIMD3(w / 2, -h / 2, 0), nn, SIMD2(1, 1))
        let d = part.vertex(SIMD3(-w / 2, -h / 2, 0), nn, SIMD2(0, 1))
        part.quad(a, d, c, b)
        return [part]
    }

    private static func read3(_ src: SCNGeometrySource) -> [SIMD3<Float>]? {
        guard src.usesFloatComponents, src.bytesPerComponent == 4, src.componentsPerVector >= 3 else { return nil }
        let n = src.vectorCount, stride = src.dataStride, off = src.dataOffset
        guard n > 0, src.data.count >= off + (n - 1) * stride + 12 else { return nil }
        var out = [SIMD3<Float>](repeating: .zero, count: n)
        src.data.withUnsafeBytes { raw in
            for k in 0..<n {
                let b = off + k * stride
                out[k] = SIMD3(raw.loadUnaligned(fromByteOffset: b, as: Float.self),
                               raw.loadUnaligned(fromByteOffset: b + 4, as: Float.self),
                               raw.loadUnaligned(fromByteOffset: b + 8, as: Float.self))
            }
        }
        return out
    }

    private static func read2(_ src: SCNGeometrySource) -> [SIMD2<Float>]? {
        guard src.usesFloatComponents, src.bytesPerComponent == 4, src.componentsPerVector >= 2 else { return nil }
        let n = src.vectorCount, stride = src.dataStride, off = src.dataOffset
        guard n > 0, src.data.count >= off + (n - 1) * stride + 8 else { return nil }
        var out = [SIMD2<Float>](repeating: .zero, count: n)
        src.data.withUnsafeBytes { raw in
            for k in 0..<n {
                let b = off + k * stride
                out[k] = SIMD2(raw.loadUnaligned(fromByteOffset: b, as: Float.self),
                               raw.loadUnaligned(fromByteOffset: b + 4, as: Float.self))
            }
        }
        return out
    }

    private static func read4(_ src: SCNGeometrySource) -> [SIMD4<Float>]? {
        guard src.usesFloatComponents, src.bytesPerComponent == 4, src.componentsPerVector >= 3 else { return nil }
        let n = src.vectorCount, stride = src.dataStride, off = src.dataOffset, comps = src.componentsPerVector
        guard n > 0, src.data.count >= off + (n - 1) * stride + comps * 4 else { return nil }
        var out = [SIMD4<Float>](repeating: SIMD4(1, 1, 1, 1), count: n)
        src.data.withUnsafeBytes { raw in
            for k in 0..<n {
                let b = off + k * stride
                out[k] = SIMD4(raw.loadUnaligned(fromByteOffset: b, as: Float.self),
                               raw.loadUnaligned(fromByteOffset: b + 4, as: Float.self),
                               raw.loadUnaligned(fromByteOffset: b + 8, as: Float.self),
                               comps >= 4 ? raw.loadUnaligned(fromByteOffset: b + 12, as: Float.self) : 1)
            }
        }
        return out
    }

    private static func indices(_ e: SCNGeometryElement) -> [UInt32]? {
        guard e.primitiveType == .triangles else { return nil }
        let count = e.primitiveCount * 3
        let bpi = e.bytesPerIndex
        guard bpi == 2 || bpi == 4, e.data.count >= count * bpi else { return nil }
        var out = [UInt32](repeating: 0, count: count)
        e.data.withUnsafeBytes { raw in
            if bpi == 2 {
                for k in 0..<count { out[k] = UInt32(raw.loadUnaligned(fromByteOffset: k * 2, as: UInt16.self)) }
            } else {
                for k in 0..<count { out[k] = raw.loadUnaligned(fromByteOffset: k * 4, as: UInt32.self) }
            }
        }
        return out
    }

    /// Mesh parts (one per element) of a custom geometry built from readable data.
    static func custom(_ g: SCNGeometry) -> [MeshPart]? {
        guard let vs = g.sources(for: .vertex).first, let pos = read3(vs) else { return nil }
        let nrm = g.sources(for: .normal).first.flatMap(read3) ?? [SIMD3<Float>](repeating: SIMD3(0, 1, 0), count: pos.count)
        let uvs = g.sources(for: .texcoord).first.flatMap(read2) ?? [SIMD2<Float>](repeating: .zero, count: pos.count)
        let cols = g.sources(for: .color).first.flatMap(read4)
        guard nrm.count == pos.count, uvs.count == pos.count else { return nil }
        if let cols, cols.count != pos.count { return nil }
        var parts: [MeshPart] = []
        for k in 0..<g.elementCount {
            guard let idx = indices(g.element(at: k)), idx.allSatisfy({ Int($0) < pos.count }) else { return nil }
            // Keep only the vertices this element uses.
            var remap: [UInt32: UInt32] = [:]
            var part = MeshPart()
            if cols != nil { part.c = [] }
            for v in idx where remap[v] == nil {
                remap[v] = UInt32(part.p.count)
                part.p.append(pos[Int(v)])
                part.n.append(nrm[Int(v)])
                part.t.append(uvs[Int(v)])
                if let cols { part.c?.append(cols[Int(v)]) }
            }
            part.i = idx.map { remap[$0]! }
            parts.append(part)
        }
        return parts
    }

    /// Mesh parts for any supported geometry, or nil when it has to stay a separate node.
    static func parts(_ g: SCNGeometry) -> [MeshPart]? {
        switch g {
        case let b as SCNBox:
            return box(Float(b.width), Float(b.height), Float(b.length), chamfer: Float(b.chamferRadius))
        case let s as SCNSphere:
            return sphere(Float(s.radius), segments: s.segmentCount)
        case let c as SCNCylinder:
            return frustum(top: Float(c.radius), bottom: Float(c.radius), height: Float(c.height), segments: c.radialSegmentCount)
        case let c as SCNCone:
            return frustum(top: Float(c.topRadius), bottom: Float(c.bottomRadius), height: Float(c.height), segments: c.radialSegmentCount)
        case let t as SCNTube:
            return tube(inner: Float(t.innerRadius), outer: Float(t.outerRadius), height: Float(t.height), segments: t.radialSegmentCount)
        case let t as SCNTorus:
            return torus(ring: Float(t.ringRadius), pipe: Float(t.pipeRadius), ringSegments: t.ringSegmentCount, pipeSegments: t.pipeSegmentCount)
        case let p as SCNPlane:
            return plane(Float(p.width), Float(p.height))
        default:
            if g is SCNCapsule || g is SCNPyramid || g is SCNFloor || g is SCNText || g is SCNShape { return nil }
            return custom(g)
        }
    }
}

/// Accumulates transformed mesh parts and outputs one geometry.
final class MeshBuilder {
    private var pos: [SIMD3<Float>] = []
    private var nrm: [SIMD3<Float>] = []
    private var uvs: [SIMD2<Float>] = []
    private var col: [SIMD4<Float>] = []
    private var groups: [(key: String, material: SCNMaterial, idx: [UInt32])] = []

    private func group(_ key: String, _ m: SCNMaterial) -> Int {
        if let k = groups.firstIndex(where: { $0.key == key }) { return k }
        groups.append((key, m, []))
        return groups.count - 1
    }

    /// Walks a node tree, merging every supported geometry; unsupported ones are cloned into `leftovers`.
    func collect(_ node: SCNNode, parent: simd_float4x4, leftovers: inout [SCNNode]) {
        let local = node.simdTransform * simd_inverse(node.simdPivot)
        let m = parent * local
        if let g = node.geometry, !node.isHidden {
            if !add(g, transform: m) {
                let c = node.clone()
                c.childNodes.forEach { $0.removeFromParentNode() }
                c.simdTransform = m
                c.simdPivot = matrix_identity_float4x4
                leftovers.append(c)
                Bake.count("leftover")
            }
        }
        for child in node.childNodes { collect(child, parent: m, leftovers: &leftovers) }
    }

    private func add(_ g: SCNGeometry, transform m: simd_float4x4) -> Bool {
        guard let parts = Prim.parts(g), !g.materials.isEmpty else { return false }
        let mats = g.materials
        let m3 = simd_float3x3(SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z),
                               SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                               SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z))
        let nm = simd_transpose(simd_inverse(m3))
        let mirrored = simd_determinant(m3) < 0
        for (k, part) in parts.enumerated() where !part.i.isEmpty {
            let mat = mats[k % mats.count]
            var key: String
            var target: SCNMaterial
            var color: SIMD4<Float>? = nil
            if Bake.isBakeMaterial(mat) {
                key = mat.name ?? "bake"
                target = mat
            } else if let c = Bake.bakeable(mat) {
                let b = Bake.bucket(for: mat)
                key = b.key
                target = b.material
                color = c
                Bake.count("baked")
            } else {
                key = "m\(ObjectIdentifier(mat).hashValue)"
                target = mat
                Bake.count("kept")
            }
            let gi = group(key, target)
            let base = UInt32(pos.count)
            for v in 0..<part.p.count {
                let p4 = m * SIMD4<Float>(part.p[v], 1)
                pos.append(SIMD3(p4.x, p4.y, p4.z))
                let nn = nm * part.n[v]
                let len = simd_length(nn)
                nrm.append(len > 1e-6 ? nn / len : SIMD3(0, 1, 0))
                uvs.append(part.t[v])
                col.append(color ?? part.c?[v] ?? SIMD4(1, 1, 1, 1))
            }
            var idx = part.i.map { $0 + base }
            if mirrored {
                var t = 0
                while t + 2 < idx.count {
                    idx.swapAt(t + 1, t + 2)
                    t += 3
                }
            }
            groups[gi].idx += idx
        }
        Bake.count("geometries")
        return true
    }

    func build() -> SCNGeometry? {
        guard !pos.isEmpty, !groups.isEmpty else { return nil }
        let n = pos.count
        func source<T>(_ arr: [T], _ semantic: SCNGeometrySource.Semantic, comps: Int) -> SCNGeometrySource {
            let stride = MemoryLayout<T>.stride
            let data = arr.withUnsafeBufferPointer { Data(buffer: $0) }
            return SCNGeometrySource(data: data, semantic: semantic, vectorCount: n, usesFloatComponents: true,
                                     componentsPerVector: comps, bytesPerComponent: 4, dataOffset: 0, dataStride: stride)
        }
        let sources = [source(pos, .vertex, comps: 3), source(nrm, .normal, comps: 3),
                       source(uvs, .texcoord, comps: 2), source(col, .color, comps: 4)]
        var elements: [SCNGeometryElement] = []
        var materials: [SCNMaterial] = []
        for g in groups where !g.idx.isEmpty {
            elements.append(SCNGeometryElement(indices: g.idx, primitiveType: .triangles))
            materials.append(g.material)
        }
        let geo = SCNGeometry(sources: sources, elements: elements)
        geo.materials = materials
        return geo
    }
}
