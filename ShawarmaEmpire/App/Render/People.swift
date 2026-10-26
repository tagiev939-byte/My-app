import SceneKit
import UIKit
import simd

enum Role {
    case customer(location: Int), vip, cook, cashier(accent: UInt32), courier
}

/// Colors and accessories of a person.
struct PersonSpec {
    let key: String
    var shirt: UInt32
    var pants: UInt32
    var skin: UInt32
    var hair: UInt32
    var hairStyle: Int
    var backpack = false
    var backpackColor: UInt32 = 0
    var glasses = false
    var chefHat = false
    var apron: UInt32?
    var cap: UInt32?
    var helmet: UInt32?
    var beret = false
    var tie: UInt32?
    var courierBox = false
    var scale: Float

    static let skins: [UInt32] = [0xF1C27D, 0xE0AC69, 0xC68642, 0x8D5524, 0xFFDBAC, 0xF5D0B0]
    static let hairs: [UInt32] = [0x2C1B10, 0x4A3423, 0x8B5A2B, 0xD6B370, 0x1C1C1C, 0xA0522D, 0x6B4E3D]
    static let shirts: [UInt32] = [0xE53935, 0x1E88E5, 0x43A047, 0xFDD835, 0x8E24AA, 0xFB8C00, 0x00ACC1, 0xEC407A,
                                   0x7CB342, 0x5C6BC0, 0xF4511E, 0x26A69A, 0xFFFFFF, 0x455A64]
    static let pantsColors: [UInt32] = [0x2B3A55, 0x3E3E3E, 0x5D4037, 0x1565C0, 0x546E7A, 0x263238, 0x6D4C41]

    init(role: Role, look raw: Int) {
        // Customers come in a limited set of looks so their baked poses can be shared.
        var look = raw
        var tag: String
        switch role {
        case .customer(let loc):
            look = abs(raw) % 40
            tag = "c\(loc)"
        case .vip: tag = "v"
        case .cook: tag = "k"
        case .cashier(let a): tag = "s\(a)"
        case .courier: tag = "r"
        }
        key = "\(tag):\(look)"
        func pick(_ list: [UInt32], _ k: Int) -> UInt32 { list[abs(look &* 31 &+ k &* 17) % list.count] }
        shirt = pick(PersonSpec.shirts, 1)
        pants = pick(PersonSpec.pantsColors, 2)
        skin = pick(PersonSpec.skins, 3)
        hair = pick(PersonSpec.hairs, 4)
        hairStyle = abs(look / 7 + look) % 5
        scale = 0.94 + Float(abs(look * 7) % 12) / 100

        switch role {
        case .customer(let loc):
            switch loc {
            case 1:
                backpack = abs(look / 3) % 10 < 6
                backpackColor = pick(PersonSpec.shirts, 7)
            case 4:
                if abs(look / 5 + look) % 10 < 6 {
                    shirt = [0x263238, 0x37474F, 0x1A237E, 0x3E2723][abs(look) % 4]
                    pants = 0x212121
                    tie = [0xC62828, 0x1565C0, 0xF9A825][abs(look / 3) % 3]
                }
            default: break
            }
            glasses = abs(look * 13 / 7) % 10 < 2
            if hairStyle == 2 { cap = pick(PersonSpec.shirts, 9) }
        case .vip:
            shirt = 0xC9A227
            pants = 0x1A1A1A
            glasses = true
            beret = true
            hairStyle = 0
        case .cook:
            shirt = 0xFFFFFF
            pants = 0x37474F
            chefHat = true
            apron = 0x3E3E3E
            hairStyle = 0
        case .cashier(let accent):
            shirt = accent
            pants = 0x263238
            cap = accent
            hairStyle = 2
        case .courier:
            shirt = 0x43A047
            pants = 0x263238
            helmet = 0x2E7D32
            hairStyle = 4
            courierBox = true
        }
    }
}

/// Quantized animation poses. Each pose of each look is baked once into a single mesh.
enum PoseID: Hashable {
    case idle(bag: Bool)
    case walk(Int, bag: Bool)
    case sit(bag: Bool)
    case work(Int)
    case serve(Int)

    static let walkFrames = 10
    static let workFrames = 8

    var bag: Bool {
        switch self {
        case .idle(let b), .walk(_, let b), .sit(let b): return b
        default: return false
        }
    }

    func with(bag b: Bool) -> PoseID {
        switch self {
        case .idle: return .idle(bag: b)
        case .walk(let k, _): return .walk(k, bag: b)
        case .sit: return .sit(bag: b)
        default: return self
        }
    }

    /// Leg and arm swing angles: (legL, legR, armL, armR).
    var angles: (Float, Float, Float, Float) {
        switch self {
        case .idle(let b):
            return (0, 0, 0, b ? -0.15 : 0)
        case .walk(let k, let b):
            let s = sin(2 * Float.pi * Float(k) / Float(PoseID.walkFrames)) * 0.6
            return (s, -s, -0.8 * s, b ? -0.15 : 0.8 * s)
        case .sit:
            return (-1.45, -1.45, -0.6, -0.7)
        case .work(let k):
            let a = 2 * Float.pi * Float(k) / Float(PoseID.workFrames)
            return (0, 0, -0.8 + 0.2 * sin(2 * a + 1), -1.1 + 0.35 * sin(a))
        case .serve(let q):
            let amt = Float(q) / 3
            return (0, 0, -0.9 * amt, -1.2 * amt)
        }
    }
}

/// Low-poly person. Every pose is a single baked mesh (1 draw call), swapped as the person moves. Faces -Z.
final class PersonView {
    let root = SCNNode()
    let rig = SCNNode()
    private let spec: PersonSpec
    private var pose: PoseID?
    private var bag = false
    private var phase = Float.random(in: 0...6)
    private var sitting = false
    private var umbrella: SCNNode?

    private static var cache: [String: SCNGeometry] = [:]

    /// Drops cached poses (called when switching locations).
    static func purge() { cache.removeAll() }

    init(role: Role, look: Int) {
        spec = PersonSpec(role: role, look: look)
        root.addChildNode(rig)
        root.scale = SCNVector3(spec.scale, spec.scale, spec.scale)
        apply(.idle(bag: false))
    }

    private func apply(_ p: PoseID) {
        guard p != pose else { return }
        pose = p
        rig.geometry = PersonView.geometry(spec, p)
    }

    private static func geometry(_ spec: PersonSpec, _ p: PoseID) -> SCNGeometry? {
        let key = spec.key + "|" + String(describing: p)
        if let g = cache[key] { return g }
        if cache.count > 2400 { cache.removeAll() }
        let g = merged(build(spec, p)).geometry
        cache[key] = g
        return g
    }

    private static func build(_ spec: PersonSpec, _ p: PoseID) -> [SCNNode] {
        let c = MaterialCache.shared
        let shirtM = c.pbr(spec.shirt, rough: 0.75)
        let pantsM = c.pbr(spec.pants, rough: 0.8)
        let skinM = c.pbr(spec.skin, rough: 0.7)
        let hairM = c.pbr(spec.hair, rough: 0.8)
        let dark = c.pbr(0x1A1A1A, rough: 0.5)

        var body: [SCNNode] = [
            Geo.box(0.34, 0.14, 0.22, pantsM, chamfer: 0.04).at(0, 0.5, 0),
            Geo.box(0.4, 0.42, 0.25, shirtM, chamfer: 0.08).at(0, 0.76, 0),
            Geo.sphere(0.17, skinM, segments: 12).at(0, 1.13, 0),
            Geo.box(0.035, 0.05, 0.02, dark).at(-0.06, 1.15, -0.158),
            Geo.box(0.035, 0.05, 0.02, dark).at(0.06, 1.15, -0.158),
        ]
        switch spec.hairStyle {
        case 0, 2:
            let h = Geo.sphere(0.178, hairM, segments: 12)
            h.scale = SCNVector3(1, 0.62, 1)
            body.append(h.at(0, 1.2, 0.02))
        case 1:
            let h = Geo.sphere(0.18, hairM, segments: 12)
            h.scale = SCNVector3(1, 0.62, 1)
            body.append(h.at(0, 1.2, 0.02))
            body.append(Geo.box(0.33, 0.32, 0.1, hairM, chamfer: 0.04).at(0, 1.04, 0.12))
        case 3:
            let h = Geo.sphere(0.178, hairM, segments: 12)
            h.scale = SCNVector3(1, 0.62, 1)
            body.append(h.at(0, 1.2, 0.02))
            body.append(Geo.sphere(0.075, hairM, segments: 8).at(0, 1.33, 0.07))
        default:
            break
        }
        if let cap = spec.cap {
            let capM = c.pbr(cap, rough: 0.6)
            body.append(Geo.cylinder(0.18, 0.09, capM, segments: 12).at(0, 1.27, 0))
            body.append(Geo.box(0.22, 0.02, 0.15, capM).at(0, 1.235, -0.18))
        }
        if spec.chefHat {
            body.append(Geo.cylinder(0.14, 0.2, M.white, segments: 12).at(0, 1.36, 0))
            body.append(Geo.sphere(0.17, M.white, segments: 10).at(0, 1.47, 0))
        }
        if let helmet = spec.helmet {
            body.append(Geo.sphere(0.2, c.pbr(helmet, rough: 0.3, metal: 0.2), segments: 12).at(0, 1.18, 0.01))
        }
        if spec.beret {
            let b = Geo.cylinder(0.19, 0.06, c.pbr(0x111111, rough: 0.6), segments: 12)
            b.eulerAngles.z = 0.2
            body.append(b.at(0.02, 1.29, 0))
        }
        if spec.glasses {
            body.append(Geo.box(0.26, 0.05, 0.02, dark).at(0, 1.16, -0.165))
        }
        if let apron = spec.apron {
            body.append(Geo.box(0.34, 0.46, 0.02, c.pbr(apron, rough: 0.8)).at(0, 0.66, -0.135))
        }
        if let tie = spec.tie {
            body.append(Geo.box(0.06, 0.28, 0.02, c.pbr(tie, rough: 0.5)).at(0, 0.8, -0.13))
        }
        if spec.backpack {
            body.append(Geo.box(0.3, 0.34, 0.14, c.pbr(spec.backpackColor, rough: 0.7), chamfer: 0.04).at(0, 0.8, 0.19))
        }
        if spec.courierBox {
            body.append(Geo.box(0.42, 0.42, 0.3, c.textured("delivery", Tex.deliveryBox, rough: 0.6), chamfer: 0.03).at(0, 0.85, 0.26))
        }

        let (aLL, aLR, aAL, aAR) = p.angles
        func limb(_ w: CGFloat, _ h: CGFloat, _ m: SCNMaterial, pivot: Float, x: Float, y: Float, angle: Float) -> SCNNode {
            let n = Geo.box(w, h, w * 1.08, m, chamfer: 0.03)
            n.pivot = SCNMatrix4MakeTranslation(0, pivot, 0)
            n.position = SCNVector3(x, y, 0)
            n.eulerAngles.x = angle
            return n
        }
        body.append(limb(0.13, 0.44, pantsM, pivot: 0.22, x: -0.09, y: 0.46, angle: aLL))
        body.append(limb(0.13, 0.44, pantsM, pivot: 0.22, x: 0.09, y: 0.46, angle: aLR))
        body.append(limb(0.1, 0.4, shirtM, pivot: 0.18, x: -0.255, y: 0.94, angle: aAL))
        let armR = limb(0.1, 0.4, shirtM, pivot: 0.18, x: 0.255, y: 0.94, angle: aAR)
        if p.bag {
            let paper = c.pbr(0xC8A27A, rough: 0.9)
            let bagNode = SCNNode()
            bagNode.add(
                Geo.box(0.2, 0.24, 0.13, paper, chamfer: 0.01).at(0, -0.12, 0),
                Geo.box(0.12, 0.02, 0.02, paper).at(0, 0.0, 0)
            )
            bagNode.position = SCNVector3(0, -0.22, -0.02)
            armR.addChildNode(bagNode)
        }
        body.append(armR)
        return body
    }

    func setBag(_ on: Bool) {
        guard on != bag else { return }
        bag = on
        if let p = pose { apply(p.with(bag: on)) }
    }

    /// Umbrella held above the head while it rains.
    func setUmbrella(_ on: Bool, look: Int) {
        if on, umbrella == nil {
            let cols: [UInt32] = [0xE53935, 0x1E88E5, 0xFDD835, 0x43A047, 0x8E24AA, 0x212121, 0xFB8C00]
            let canopy = MaterialCache.shared.pbr(cols[abs(look) % cols.count], rough: 0.55)
            let u = merged([
                Geo.cylinder(0.016, 0.95, M.black, segments: 6).at(0, 0.47, 0),
                Geo.cone(0.02, 0.5, 0.2, canopy, segments: 10).at(0, 0.98, 0),
                Geo.sphere(0.025, M.black, segments: 6).at(0, 1.09, 0),
            ], shadows: true)
            u.position = SCNVector3(0.2, 0.86, -0.05)
            u.eulerAngles.z = 0.12
            rig.addChildNode(u)
            umbrella = u
        } else if !on, let u = umbrella {
            u.removeFromParentNode()
            umbrella = nil
        }
    }

    /// Small hop used for feedback (tap on a cook).
    func hop() {
        guard root.action(forKey: "hop") == nil else { return }
        let up = SCNAction.moveBy(x: 0, y: 0.18, z: 0, duration: 0.09)
        up.timingMode = .easeOut
        let down = SCNAction.moveBy(x: 0, y: -0.18, z: 0, duration: 0.12)
        down.timingMode = .easeIn
        root.runAction(.sequence([up, down]), forKey: "hop")
    }

    private static func frame(_ phase: Float, _ count: Int) -> Int {
        let t = phase / (2 * Float.pi)
        let f = t - floor(t)
        return min(count - 1, max(0, Int(f * Float(count))))
    }

    /// Walking / idle animation driven every frame.
    func animate(moving: Bool, speed: Float, dt: Float) {
        guard !sitting else { return }
        if moving {
            phase += dt * speed * 6.2
            apply(.walk(PersonView.frame(phase, PoseID.walkFrames), bag: bag))
            rig.position.y = abs(sin(phase)) * 0.045
        } else {
            phase += dt * 1.5
            apply(.idle(bag: bag))
            rig.position.y = sin(phase) * 0.006
        }
    }

    func sit(_ on: Bool) {
        guard on != sitting else { return }
        sitting = on
        apply(on ? .sit(bag: bag) : .idle(bag: bag))
        rig.position.y = on ? -0.02 : 0
    }

    /// Cooking motion for kitchen staff.
    func work(time: Double, active: Bool, dt: Float) {
        let t = Float(time) + phase
        if active {
            apply(.work(PersonView.frame(t * 13, PoseID.workFrames)))
            rig.position.y = abs(sin(t * 6.5)) * 0.015
            rig.eulerAngles.y = sin(t * 1.3) * 0.12
        } else {
            apply(.idle(bag: false))
            rig.position.y = sin(t * 1.5) * 0.006
            rig.eulerAngles.y = sin(t * 0.7) * 0.25
        }
    }

    /// Cashier handing over an order.
    func serve(_ amount: Float) {
        let q = Int((max(0, min(1, amount)) * 3).rounded())
        apply(q == 0 ? .idle(bag: false) : .serve(q))
    }
}
