import SceneKit
import simd

// MARK: - Mesh builder

/// Accumulates flat-shaded quads into one geometry with several material elements.
struct MeshBuilder {
    private(set) var positions: [SCNVector3] = []
    private(set) var normals: [SCNVector3] = []
    private(set) var uvs: [CGPoint] = []
    private(set) var indices: [[UInt32]]

    init(elements: Int) {
        indices = Array(repeating: [], count: elements)
    }

    var isEmpty: Bool { positions.isEmpty }

    /// Quad a-b-c-d (given in order around the edge). Winding is fixed so the face points along `n`.
    mutating func quad(_ e: Int, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>,
                       n: SIMD3<Float>, uv: [SIMD2<Float>]? = nil) {
        let base = UInt32(positions.count)
        let pts = [a, b, c, d]
        let t = uv ?? [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1)]
        for i in 0..<4 {
            positions.append(SCNVector3(pts[i].x, pts[i].y, pts[i].z))
            normals.append(SCNVector3(n.x, n.y, n.z))
            uvs.append(CGPoint(x: CGFloat(t[i].x), y: CGFloat(t[i].y)))
        }
        if simd_dot(simd_cross(b - a, c - a), n) >= 0 {
            indices[e] += [base, base + 1, base + 2, base, base + 2, base + 3]
        } else {
            indices[e] += [base, base + 2, base + 1, base, base + 3, base + 2]
        }
    }

    func geometry(materials: [SCNMaterial]) -> SCNGeometry? {
        guard !positions.isEmpty else { return nil }
        var elements: [SCNGeometryElement] = []
        var mats: [SCNMaterial] = []
        for (i, idx) in indices.enumerated() where !idx.isEmpty {
            elements.append(SCNGeometryElement(indices: idx, primitiveType: .triangles))
            mats.append(materials[i])
        }
        guard !elements.isEmpty else { return nil }
        let g = SCNGeometry(sources: [SCNGeometrySource(vertices: positions),
                                      SCNGeometrySource(normals: normals),
                                      SCNGeometrySource(textureCoordinates: uvs)],
                            elements: elements)
        g.materials = mats
        return g
    }
}

/// Local tile space (output towards -Z) to world space.
struct TileXf {
    let c: Float
    let s: Float
    let off: SIMD3<Float>

    init(yaw: Float, offset: SIMD3<Float>) {
        c = cos(yaw)
        s = sin(yaw)
        off = offset
    }

    func n(_ v: SIMD3<Float>) -> SIMD3<Float> { SIMD3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c) }
    func p(_ v: SIMD3<Float>) -> SIMD3<Float> { n(v) + off }
}

extension MeshBuilder {
    /// Axis-aligned box in local space without the bottom face.
    mutating func box(_ e: Int, _ lo: SIMD3<Float>, _ hi: SIMD3<Float>, _ xf: TileXf) {
        func P(_ x: Float, _ y: Float, _ z: Float) -> SIMD3<Float> { xf.p(SIMD3(x, y, z)) }
        quad(e, P(lo.x, hi.y, lo.z), P(hi.x, hi.y, lo.z), P(hi.x, hi.y, hi.z), P(lo.x, hi.y, hi.z), n: xf.n(SIMD3(0, 1, 0)))
        quad(e, P(hi.x, lo.y, lo.z), P(hi.x, lo.y, hi.z), P(hi.x, hi.y, hi.z), P(hi.x, hi.y, lo.z), n: xf.n(SIMD3(1, 0, 0)))
        quad(e, P(lo.x, lo.y, lo.z), P(lo.x, hi.y, lo.z), P(lo.x, hi.y, hi.z), P(lo.x, lo.y, hi.z), n: xf.n(SIMD3(-1, 0, 0)))
        quad(e, P(lo.x, lo.y, hi.z), P(lo.x, hi.y, hi.z), P(hi.x, hi.y, hi.z), P(hi.x, lo.y, hi.z), n: xf.n(SIMD3(0, 0, 1)))
        quad(e, P(lo.x, lo.y, lo.z), P(hi.x, lo.y, lo.z), P(hi.x, hi.y, lo.z), P(lo.x, hi.y, lo.z), n: xf.n(SIMD3(0, 0, -1)))
    }

    /// Wall along x = const between z0...z1 and y0...y1, facing `nx` (+1 or -1).
    mutating func wallX(_ e: Int, x: Float, z0: Float, z1: Float, y0: Float, y1: Float, nx: Float, _ xf: TileXf) {
        quad(e, xf.p(SIMD3(x, y0, z0)), xf.p(SIMD3(x, y0, z1)), xf.p(SIMD3(x, y1, z1)), xf.p(SIMD3(x, y1, z0)),
             n: xf.n(SIMD3(nx, 0, 0)))
    }

    /// Horizontal rectangle at height y.
    mutating func flat(_ e: Int, x0: Float, x1: Float, z0: Float, z1: Float, y: Float, _ xf: TileXf, uv: [SIMD2<Float>]? = nil) {
        quad(e, xf.p(SIMD3(x0, y, z0)), xf.p(SIMD3(x1, y, z0)), xf.p(SIMD3(x1, y, z1)), xf.p(SIMD3(x0, y, z1)),
             n: xf.n(SIMD3(0, 1, 0)), uv: uv)
    }

    /// Quarter ring around the tile corner `c` (local XZ). Angle 0 is the input edge, pi/2 the output edge.
    mutating func arc(_ e: Int, c: SIMD2<Float>, sx: Float, r0: Float, r1: Float, y0: Float, y1: Float,
                      segments: Int, _ xf: TileXf, top: Bool, outer: Bool, inner: Bool, surfaceUV: Bool = false) {
        func pt(_ r: Float, _ t: Float, _ y: Float) -> SIMD3<Float> {
            xf.p(SIMD3(c.x + r * sx * sin(t), y, c.y + r * cos(t)))
        }
        let quarter = Float.pi / 2
        for i in 0..<segments {
            let ta = Float(i) / Float(segments) * quarter
            let tb = Float(i + 1) / Float(segments) * quarter
            let tm = (ta + tb) / 2
            let radial = xf.n(SIMD3(sx * sin(tm), 0, cos(tm)))
            if top {
                var uv: [SIMD2<Float>]? = nil
                if surfaceUV {
                    func u(_ r: Float) -> Float { sx > 0 ? (r - 0.1) / 0.8 : 1 - (r - 0.1) / 0.8 }
                    let va = 1 - ta / quarter, vb = 1 - tb / quarter
                    uv = [SIMD2(u(r0), va), SIMD2(u(r1), va), SIMD2(u(r1), vb), SIMD2(u(r0), vb)]
                }
                quad(e, pt(r0, ta, y1), pt(r1, ta, y1), pt(r1, tb, y1), pt(r0, tb, y1), n: xf.n(SIMD3(0, 1, 0)), uv: uv)
            }
            if outer {
                quad(e, pt(r1, ta, y0), pt(r1, tb, y0), pt(r1, tb, y1), pt(r1, ta, y1), n: radial)
            }
            if inner {
                quad(e, pt(r0, ta, y0), pt(r0, tb, y0), pt(r0, tb, y1), pt(r0, ta, y1), n: -radial)
            }
        }
    }
}

// MARK: - Conveyor meshes

struct BeltInfo {
    var shape: BeltShape
    var backFeed: Bool
    var leftFeed: Bool
    var rightFeed: Bool
    var frontOpen: Bool
}

enum BeltMesher {
    static let surfaceY: Float = 0.101
    static let bodyY: Float = 0.1
    static let railTop: Float = 0.165
    static let half: Float = 0.47
    static let lane: Float = 0.4

    /// How a conveyor connects to its neighbours.
    static func info(_ b: Building, _ world: World) -> BeltInfo {
        func feeds(_ side: Dir) -> Bool {
            guard let n = world.building(b.x + side.dx, b.y + side.dy) else { return false }
            let toward = side.opposite
            switch n.type {
            case .conveyor, .drill, .smelter, .assembler: return n.dir == toward
            case .splitter: return n.dir == toward || n.dir.cw == toward || n.dir.ccw == toward
            case .junction: return true
            case .market: return false
            }
        }
        let back = feeds(b.dir.opposite)
        let left = feeds(b.dir.ccw)
        let right = feeds(b.dir.cw)
        var shape: BeltShape = .straight
        if !back {
            if left && !right { shape = .left }
            if right && !left { shape = .right }
        }
        let front: Bool = {
            guard let n = world.building(b.x + b.dir.dx, b.y + b.dir.dy) else { return false }
            let side = b.dir.opposite
            switch n.type {
            case .conveyor: return n.dir != side
            case .splitter: return n.dir.opposite == side
            case .junction, .market: return true
            case .smelter, .assembler: return n.dir != side
            case .drill: return false
            }
        }()
        return BeltInfo(shape: shape, backFeed: back, leftFeed: left, rightFeed: right, frontOpen: front)
    }

    /// Appends one conveyor tile. Elements: 0 = belt surface, 1 = body, 2 = rails.
    static func append(_ mb: inout MeshBuilder, info: BeltInfo, xf: TileXf) {
        let h = half, l = lane
        switch info.shape {
        case .straight:
            // Surface
            mb.flat(0, x0: -l, x1: l, z0: -0.5, z1: 0.5, y: surfaceY, xf,
                    uv: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1)])
            // Sides: rails with an opening where another line joins
            for (side, feed) in [(Float(-1), info.leftFeed), (Float(1), info.rightFeed)] {
                let rx0 = side < 0 ? -h : l
                let rx1 = side < 0 ? -l : h
                let wallX = side * h
                if feed {
                    for (z0, z1) in [(Float(-0.5), -l), (l, Float(0.5))] {
                        mb.box(2, SIMD3(rx0, bodyY, z0), SIMD3(rx1, railTop, z1), xf)
                        mb.wallX(1, x: wallX, z0: z0, z1: z1, y0: 0, y1: bodyY, nx: side, xf)
                    }
                    // Throat: belt surface continues to the tile edge
                    let tx0 = side < 0 ? -0.5 : l
                    let tx1 = side < 0 ? -l : 0.5
                    let v0: Float = side < 0 ? 1 : 0.9
                    let v1: Float = side < 0 ? 0.9 : 1
                    mb.flat(0, x0: tx0, x1: tx1, z0: -l, z1: l, y: surfaceY, xf,
                            uv: [SIMD2(0, v0), SIMD2(0, v1), SIMD2(1, v1), SIMD2(1, v0)])
                } else {
                    mb.box(2, SIMD3(rx0, bodyY, -0.5), SIMD3(rx1, railTop, 0.5), xf)
                    mb.wallX(1, x: wallX, z0: -0.5, z1: 0.5, y0: 0, y1: bodyY, nx: side, xf)
                }
            }
            if !info.backFeed {
                mb.box(2, SIMD3(-h, 0, 0.44), SIMD3(h, 0.15, 0.5), xf)
            }
        case .left, .right:
            let sx: Float = info.shape == .left ? 1 : -1
            let c = SIMD2<Float>(info.shape == .left ? -0.5 : 0.5, -0.5)
            mb.arc(0, c: c, sx: sx, r0: 0.1, r1: 0.9, y0: surfaceY, y1: surfaceY, segments: 10, xf,
                   top: true, outer: false, inner: false, surfaceUV: true)
            mb.arc(1, c: c, sx: sx, r0: 0.03, r1: 0.97, y0: 0, y1: bodyY, segments: 10, xf,
                   top: false, outer: true, inner: true)
            mb.arc(2, c: c, sx: sx, r0: 0.9, r1: 0.97, y0: bodyY, y1: railTop, segments: 10, xf,
                   top: true, outer: true, inner: true)
            mb.arc(2, c: c, sx: sx, r0: 0.03, r1: 0.1, y0: bodyY, y1: railTop, segments: 6, xf,
                   top: true, outer: true, inner: true)
        }
        if !info.frontOpen {
            mb.box(2, SIMD3(-h, 0, -0.5), SIMD3(h, 0.15, -0.44), xf)
        }
    }
}
