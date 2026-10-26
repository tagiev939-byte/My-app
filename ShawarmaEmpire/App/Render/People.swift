import SceneKit
import UIKit
import simd

enum Role {
    case customer(location: Int), vip, cook, cashier(accent: UInt32), courier
}

/// Low-poly person with animated limbs. Faces -Z.
final class PersonView {
    let root = SCNNode()
    let rig = SCNNode()
    private let legL: SCNNode
    private let legR: SCNNode
    private let armL: SCNNode
    private let armR: SCNNode
    private var bag: SCNNode?
    private var phase = Float.random(in: 0...6)
    private var amp: Float = 0
    private var sitting = false

    static let skins: [UInt32] = [0xF1C27D, 0xE0AC69, 0xC68642, 0x8D5524, 0xFFDBAC, 0xF5D0B0]
    static let hairs: [UInt32] = [0x2C1B10, 0x4A3423, 0x8B5A2B, 0xD6B370, 0x1C1C1C, 0xA0522D, 0x6B4E3D]
    static let shirts: [UInt32] = [0xE53935, 0x1E88E5, 0x43A047, 0xFDD835, 0x8E24AA, 0xFB8C00, 0x00ACC1, 0xEC407A,
                                   0x7CB342, 0x5C6BC0, 0xF4511E, 0x26A69A, 0xFFFFFF, 0x455A64]
    static let pants: [UInt32] = [0x2B3A55, 0x3E3E3E, 0x5D4037, 0x1565C0, 0x546E7A, 0x263238, 0x6D4C41]

    init(role: Role, look: Int) {
        let c = MaterialCache.shared
        func pick(_ list: [UInt32], _ k: Int) -> UInt32 { list[abs(look &* 31 &+ k &* 17) % list.count] }
        var shirt = pick(PersonView.shirts, 1)
        var pantsC = pick(PersonView.pants, 2)
        let skin = pick(PersonView.skins, 3)
        let hairC = pick(PersonView.hairs, 4)
        var hairStyle = abs(look / 7) % 5
        var backpack = false, glasses = false, chefHat = false, apron: UInt32? = nil, cap: UInt32? = nil
        var helmet: UInt32? = nil, beret = false, tie: UInt32? = nil

        switch role {
        case .customer(let loc):
            switch loc {
            case 1: backpack = abs(look / 3) % 10 < 6
            case 4:
                if abs(look / 5) % 10 < 6 {
                    shirt = [0x263238, 0x37474F, 0x1A237E, 0x3E2723][abs(look) % 4]
                    pantsC = 0x212121
                    tie = [0xC62828, 0x1565C0, 0xF9A825][abs(look / 11) % 3]
                }
            default: break
            }
            glasses = abs(look / 13) % 10 < 2
            if hairStyle == 2 { cap = pick(PersonView.shirts, 9) }
        case .vip:
            shirt = 0xC9A227
            pantsC = 0x1A1A1A
            glasses = true
            beret = true
            hairStyle = 0
        case .cook:
            shirt = 0xFFFFFF
            pantsC = 0x37474F
            chefHat = true
            apron = 0x3E3E3E
            hairStyle = 0
        case .cashier(let accent):
            shirt = accent
            pantsC = 0x263238
            cap = accent
            hairStyle = 2
        case .courier:
            shirt = 0x43A047
            pantsC = 0x263238
            helmet = 0x2E7D32
            hairStyle = 4
        }

        let shirtM = c.pbr(shirt, rough: 0.75)
        let pantsM = c.pbr(pantsC, rough: 0.8)
        let skinM = c.pbr(skin, rough: 0.7)
        let hairM = c.pbr(hairC, rough: 0.8)
        let dark = c.pbr(0x1A1A1A, rough: 0.5)

        var body: [SCNNode] = [
            Geo.box(0.34, 0.14, 0.22, pantsM, chamfer: 0.04).at(0, 0.5, 0),
            Geo.box(0.4, 0.42, 0.25, shirtM, chamfer: 0.08).at(0, 0.76, 0),
            Geo.sphere(0.17, skinM, segments: 14).at(0, 1.13, 0),
            Geo.box(0.035, 0.05, 0.02, dark).at(-0.06, 1.15, -0.158),
            Geo.box(0.035, 0.05, 0.02, dark).at(0.06, 1.15, -0.158),
        ]
        switch hairStyle {
        case 0, 2:
            let h = Geo.sphere(0.178, hairM, segments: 14)
            h.scale = SCNVector3(1, 0.62, 1)
            body.append(h.at(0, 1.2, 0.02))
        case 1:
            let h = Geo.sphere(0.18, hairM, segments: 14)
            h.scale = SCNVector3(1, 0.62, 1)
            body.append(h.at(0, 1.2, 0.02))
            body.append(Geo.box(0.33, 0.32, 0.1, hairM, chamfer: 0.04).at(0, 1.04, 0.12))
        case 3:
            let h = Geo.sphere(0.178, hairM, segments: 14)
            h.scale = SCNVector3(1, 0.62, 1)
            body.append(h.at(0, 1.2, 0.02))
            body.append(Geo.sphere(0.075, hairM, segments: 10).at(0, 1.33, 0.07))
        default:
            break
        }
        if let cap {
            let capM = c.pbr(cap, rough: 0.6)
            body.append(Geo.cylinder(0.18, 0.09, capM, segments: 14).at(0, 1.27, 0))
            body.append(Geo.box(0.22, 0.02, 0.15, capM).at(0, 1.235, -0.18))
        }
        if chefHat {
            body.append(Geo.cylinder(0.14, 0.2, M.white, segments: 14).at(0, 1.36, 0))
            body.append(Geo.sphere(0.17, M.white, segments: 12).at(0, 1.47, 0))
        }
        if let helmet {
            body.append(Geo.sphere(0.2, c.pbr(helmet, rough: 0.3, metal: 0.2), segments: 14).at(0, 1.18, 0.01))
        }
        if beret {
            let b = Geo.cylinder(0.19, 0.06, c.pbr(0x111111, rough: 0.6), segments: 14)
            b.eulerAngles.z = 0.2
            body.append(b.at(0.02, 1.29, 0))
        }
        if glasses {
            body.append(Geo.box(0.26, 0.05, 0.02, dark).at(0, 1.16, -0.165))
        }
        if let apron {
            body.append(Geo.box(0.34, 0.46, 0.02, c.pbr(apron, rough: 0.8)).at(0, 0.66, -0.135))
        }
        if let tie {
            body.append(Geo.box(0.06, 0.28, 0.02, c.pbr(tie, rough: 0.5)).at(0, 0.8, -0.13))
        }
        if backpack {
            body.append(Geo.box(0.3, 0.34, 0.14, c.pbr(pick(PersonView.shirts, 7), rough: 0.7), chamfer: 0.04).at(0, 0.8, 0.19))
        }
        if case .courier = role {
            body.append(Geo.box(0.42, 0.42, 0.3, MaterialCache.shared.textured("delivery", Tex.deliveryBox, rough: 0.6), chamfer: 0.03).at(0, 0.85, 0.26))
        }

        legL = Geo.box(0.13, 0.44, 0.14, pantsM, chamfer: 0.03)
        legR = Geo.box(0.13, 0.44, 0.14, pantsM, chamfer: 0.03)
        armL = Geo.box(0.1, 0.4, 0.11, shirtM, chamfer: 0.03)
        armR = Geo.box(0.1, 0.4, 0.11, shirtM, chamfer: 0.03)
        for limb in [legL, legR] { limb.pivot = SCNMatrix4MakeTranslation(0, 0.22, 0) }
        for limb in [armL, armR] { limb.pivot = SCNMatrix4MakeTranslation(0, 0.18, 0) }
        for limb in [armL, armR] { limb.castsShadow = false }
        legL.position = SCNVector3(-0.09, 0.46, 0)
        legR.position = SCNVector3(0.09, 0.46, 0)
        armL.position = SCNVector3(-0.255, 0.94, 0)
        armR.position = SCNVector3(0.255, 0.94, 0)

        rig.addChildNode(merged(body))
        rig.add(legL, legR, armL, armR)
        root.addChildNode(rig)
        let s: Float = 0.94 + Float(abs(look / 19) % 12) / 100
        root.scale = SCNVector3(s, s, s)
    }

    func setBag(_ on: Bool) {
        if on, bag == nil {
            let b = merged([
                Geo.box(0.2, 0.24, 0.13, MaterialCache.shared.pbr(0xC8A27A, rough: 0.9), chamfer: 0.01).at(0, -0.12, 0),
                Geo.box(0.12, 0.02, 0.02, MaterialCache.shared.pbr(0xC8A27A, rough: 0.9)).at(0, 0.0, 0),
            ], shadows: false)
            b.position = SCNVector3(0, -0.22, -0.02)
            armR.addChildNode(b)
            bag = b
        } else if !on, let b = bag {
            b.removeFromParentNode()
            bag = nil
        }
    }

    private var umbrella: SCNNode?

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

    /// Walking / idle animation driven every frame.
    func animate(moving: Bool, speed: Float, dt: Float) {
        guard !sitting else { return }
        let target: Float = moving ? 0.6 : 0
        amp += (target - amp) * min(1, dt * 10)
        if moving { phase += dt * speed * 6.2 } else { phase += dt * 1.5 }
        let s = sin(phase) * amp
        legL.eulerAngles.x = s
        legR.eulerAngles.x = -s
        armL.eulerAngles.x = -s * 0.8
        armR.eulerAngles.x = bag != nil ? -0.15 : s * 0.8
        rig.position.y = moving ? abs(sin(phase)) * 0.05 * amp : sin(phase) * 0.006
    }

    func sit(_ on: Bool) {
        guard on != sitting else { return }
        sitting = on
        legL.eulerAngles.x = on ? -1.45 : 0
        legR.eulerAngles.x = on ? -1.45 : 0
        armL.eulerAngles.x = on ? -0.6 : 0
        armR.eulerAngles.x = on ? -0.7 : 0
        rig.position.y = on ? -0.02 : 0
    }

    /// Cooking motion for kitchen staff.
    func work(time: Double, active: Bool, dt: Float) {
        let t = Float(time) + phase
        if active {
            armR.eulerAngles.x = -1.1 + sin(t * 13) * 0.35
            armL.eulerAngles.x = -0.8 + sin(t * 7 + 1) * 0.2
            rig.position.y = abs(sin(t * 6.5)) * 0.015
            rig.eulerAngles.y = sin(t * 1.3) * 0.12
        } else {
            armR.eulerAngles.x *= 1 - min(1, dt * 6)
            armL.eulerAngles.x *= 1 - min(1, dt * 6)
            rig.position.y = sin(t * 1.5) * 0.006
            rig.eulerAngles.y = sin(t * 0.7) * 0.25
        }
    }

    /// Cashier handing over an order.
    func serve(_ amount: Float) {
        armR.eulerAngles.x = -1.2 * amount
        armL.eulerAngles.x = -0.9 * amount
    }
}
