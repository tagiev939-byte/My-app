import SceneKit
import UIKit
import simd

// MARK: - Dishes

final class DishModels {
    private var templates: [Dish: SCNNode] = [:]

    func node(_ d: Dish) -> SCNNode {
        if let t = templates[d] { return t.clone() }
        let t = merged([make(d)], shadows: false)
        templates[d] = t
        return t.clone()
    }

    private func mat(_ hex: UInt32, rough: CGFloat = 0.6, metal: CGFloat = 0) -> SCNMaterial {
        MaterialCache.shared.pbr(hex, rough: rough, metal: metal)
    }

    private func make(_ d: Dish) -> SCNNode {
        let r = SCNNode()
        let bread = mat(0xE9C98B), paper = mat(0xFAFAF7, rough: 0.9), meat = mat(0x8C4A23), green = mat(0x5DBB46)
        switch d {
        case .shawarma, .shawarmaXL:
            let wrap = SCNNode()
            wrap.add(
                Geo.cylinder(0.056, 0.24, bread, segments: 14).at(0, 0.12, 0),
                Geo.cylinder(0.06, 0.12, paper, segments: 14).at(0, 0.07, 0),
                Geo.cylinder(0.05, 0.02, meat, segments: 12).at(0, 0.24, 0),
                Geo.sphere(0.02, green, segments: 6).at(0.02, 0.255, 0.01),
                Geo.sphere(0.015, mat(0xE53935), segments: 6).at(-0.018, 0.252, -0.01)
            )
            if d == .shawarmaXL {
                wrap.addChildNode(Geo.cylinder(0.062, 0.025, mat(0xD32F2F), segments: 14).at(0, 0.1, 0))
                wrap.scale = SCNVector3(1.25, 1.2, 1.25)
            }
            wrap.eulerAngles.z = 0.22
            r.addChildNode(wrap)
        case .cola, .lemonade:
            let cup = d == .cola ? mat(0xD32F2F) : mat(0xFFEB3B, rough: 0.1, metal: 0.0)
            r.add(
                Geo.cone(0.062, 0.046, 0.16, cup, segments: 16).at(0, 0.08, 0),
                Geo.cylinder(0.064, 0.016, paper, segments: 16).at(0, 0.165, 0),
                Geo.cylinder(0.008, 0.11, d == .cola ? paper : mat(0x4CAF50), segments: 6).at(0.015, 0.21, 0).rot(0, 0, -0.2)
            )
            if d == .lemonade {
                r.addChildNode(Geo.cylinder(0.035, 0.008, mat(0xFFF176), segments: 12).at(0.05, 0.17, 0).rot(0, 0, Float.pi / 2))
            }
        case .fries:
            r.addChildNode(Geo.box(0.12, 0.11, 0.08, mat(0xD32F2F), chamfer: 0.01).at(0, 0.055, 0))
            for k in 0..<7 {
                let x = -0.045 + Float(k) * 0.015
                let h = 0.08 + CGFloat(hash01(k, 1)) * 0.04
                r.addChildNode(Geo.box(0.014, h, 0.014, mat(0xF6C343)).at(x, 0.11 + Float(h) / 2 - 0.02, Float(hash01(k, 2)) * 0.03 - 0.015).rot(0, 0, (Float(k) - 3) * 0.06))
            }
        case .burger:
            let bun = mat(0xD99A4E)
            r.add(
                Geo.cylinder(0.09, 0.03, bun, segments: 18).at(0, 0.015, 0),
                Geo.cylinder(0.094, 0.026, mat(0x6D3B1E), segments: 18).at(0, 0.043, 0),
                Geo.box(0.16, 0.008, 0.16, mat(0xFFC107)).at(0, 0.059, 0).rot(0, Float.pi / 4, 0),
                Geo.cylinder(0.098, 0.01, green, segments: 18).at(0, 0.067, 0),
                Geo.sphere(0.09, bun, segments: 16).at(0, 0.072, 0).scaled(1)
            )
            r.childNodes.last?.scale = SCNVector3(1, 0.55, 1)
        case .hotdog:
            let bun = Geo.cylinder(0.042, 0.22, mat(0xD99A4E), segments: 14)
            bun.eulerAngles.z = Float.pi / 2
            let sausage = Geo.cylinder(0.028, 0.27, mat(0xB0472A), segments: 12)
            sausage.eulerAngles.z = Float.pi / 2
            r.add(bun.at(0, 0.04, 0), sausage.at(0, 0.07, 0),
                  Geo.box(0.2, 0.008, 0.014, mat(0xFFD600)).at(0, 0.097, 0))
        case .tea, .coffee:
            if d == .tea {
                r.add(
                    Geo.cylinder(0.085, 0.01, paper, segments: 18).at(0, 0.005, 0),
                    Geo.cylinder(0.05, 0.075, paper, segments: 16).at(0, 0.047, 0),
                    Geo.cylinder(0.044, 0.004, mat(0x8D5A2B, rough: 0.1), segments: 16).at(0, 0.084, 0),
                    Geo.torus(0.022, 0.007, paper).at(0.058, 0.05, 0).rot(Float.pi / 2, 0, 0)
                )
            } else {
                r.add(
                    Geo.cone(0.052, 0.04, 0.13, paper, segments: 16).at(0, 0.065, 0),
                    Geo.cylinder(0.05, 0.04, mat(0x8D6E63), segments: 16).at(0, 0.07, 0),
                    Geo.cylinder(0.055, 0.016, mat(0x4E342E), segments: 16).at(0, 0.136, 0)
                )
            }
        case .donut:
            r.add(
                Geo.torus(0.058, 0.032, mat(0xD9A05B)).at(0, 0.032, 0),
                Geo.torus(0.058, 0.026, mat(0xF48FB1, rough: 0.35)).at(0, 0.044, 0)
            )
            for k in 0..<6 {
                let a = Float(k) / 6 * 2 * Float.pi
                let cols: [UInt32] = [0xFFFFFF, 0x4FC3F7, 0xFFEB3B]
                r.addChildNode(Geo.box(0.012, 0.006, 0.004, mat(cols[k % 3])).at(cos(a) * 0.058, 0.068, sin(a) * 0.058).rot(0, a, 0))
            }
        case .pizza:
            r.add(
                Geo.cylinder(0.13, 0.02, mat(0xE0A060), segments: 24).at(0, 0.01, 0),
                Geo.cylinder(0.115, 0.008, mat(0xF2C14E, rough: 0.4), segments: 24).at(0, 0.023, 0)
            )
            for k in 0..<6 {
                let a = Float(k) / 6 * 2 * Float.pi + 0.3
                let rr: Float = k % 2 == 0 ? 0.07 : 0.045
                r.addChildNode(Geo.cylinder(0.02, 0.006, mat(0xC62828), segments: 10).at(cos(a) * rr, 0.029, sin(a) * rr))
            }
            r.addChildNode(Geo.sphere(0.012, green, segments: 6).at(0, 0.03, 0))
        case .nuggets:
            r.addChildNode(Geo.box(0.13, 0.055, 0.09, mat(0xFFB300), chamfer: 0.008).at(0, 0.028, 0))
            for k in 0..<4 {
                r.addChildNode(Geo.node(Geo.blob(radius: 0.028, squash: 0.7, seed: 40 + k), mat(0xD9952E)).at(-0.04 + Float(k) * 0.027, 0.07, Float(k % 2) * 0.02 - 0.01))
            }
        case .milkshake:
            r.add(
                Geo.cone(0.05, 0.04, 0.15, mat(0xF8BBD0, rough: 0.3), segments: 16).at(0, 0.075, 0),
                Geo.sphere(0.048, mat(0xFFFFFF, rough: 0.8), segments: 12).at(0, 0.16, 0),
                Geo.sphere(0.016, mat(0xD50000, rough: 0.3), segments: 8).at(0, 0.21, 0),
                Geo.cylinder(0.007, 0.12, mat(0x42A5F5), segments: 6).at(0.02, 0.2, 0).rot(0, 0, -0.25)
            )
        case .icecream:
            r.add(
                Geo.cone(0.045, 0.004, 0.12, mat(0xD7A15A), segments: 12).at(0, 0.06, 0),
                Geo.sphere(0.045, mat(0xF8BBD0, rough: 0.7), segments: 12).at(0, 0.13, 0),
                Geo.sphere(0.04, mat(0xFFF59D, rough: 0.7), segments: 12).at(0, 0.19, 0)
            )
        case .plov:
            r.add(
                Geo.cylinder(0.12, 0.015, paper, segments: 20).at(0, 0.008, 0),
                Geo.sphere(0.09, mat(0xE5A13A, rough: 0.8), segments: 14).at(0, 0.02, 0)
            )
            r.childNodes.last?.scale = SCNVector3(1, 0.45, 1)
            for k in 0..<5 {
                let a = Float(k) * 1.3
                r.addChildNode(Geo.box(0.012, 0.012, 0.04, mat(0xFF7043)).at(cos(a) * 0.05, 0.055, sin(a) * 0.05).rot(0, a, 0))
            }
            r.addChildNode(Geo.node(Geo.blob(radius: 0.025, squash: 0.8, seed: 7), mat(0x6D3B1E)).at(0.01, 0.065, -0.01))
        case .steak:
            r.add(
                Geo.cylinder(0.12, 0.015, paper, segments: 20).at(0, 0.008, 0),
                Geo.box(0.14, 0.03, 0.09, mat(0x8D3B2B, rough: 0.6), chamfer: 0.012).at(-0.01, 0.03, 0).rot(0, 0.3, 0),
                Geo.sphere(0.022, green, segments: 8).at(0.07, 0.03, 0.04)
            )
            for k in 0..<3 {
                r.addChildNode(Geo.box(0.11, 0.004, 0.008, mat(0x3E1A0E)).at(-0.01, 0.046, -0.025 + Float(k) * 0.025).rot(0, 0.3 + 0.6, 0))
            }
        case .cheesecake:
            r.add(
                Geo.box(0.12, 0.06, 0.1, mat(0xFFE0B2, rough: 0.7), chamfer: 0.01).at(0, 0.03, 0),
                Geo.box(0.12, 0.012, 0.1, mat(0xC62828, rough: 0.3)).at(0, 0.065, 0),
                Geo.sphere(0.018, mat(0xE53935, rough: 0.3), segments: 8).at(0, 0.085, 0)
            )
        case .sushi:
            r.addChildNode(Geo.box(0.18, 0.015, 0.08, mat(0xB07A45)).at(0, 0.008, 0))
            for k in 0..<3 {
                let x = -0.05 + Float(k) * 0.05
                r.add(
                    Geo.cylinder(0.023, 0.035, mat(0x1B2A1B), segments: 12).at(x, 0.033, 0),
                    Geo.cylinder(0.019, 0.037, mat(0xFAFAFA, rough: 0.8), segments: 12).at(x, 0.034, 0),
                    Geo.cylinder(0.008, 0.039, mat(0xFF7043), segments: 8).at(x, 0.034, 0)
                )
            }
        case .ramen:
            r.add(
                Geo.cylinder(0.075, 0.06, mat(0xB71C1C, rough: 0.4), segments: 20).at(0, 0.03, 0),
                Geo.cylinder(0.068, 0.006, mat(0xF4A261, rough: 0.2), segments: 20).at(0, 0.06, 0),
                Geo.sphere(0.022, mat(0xFFFFFF), segments: 8).at(0.02, 0.064, 0.02),
                Geo.sphere(0.012, mat(0xFFB300), segments: 8).at(0.02, 0.075, 0.02),
                Geo.box(0.004, 0.004, 0.18, mat(0x6D4C41)).at(-0.02, 0.09, 0).rot(0.3, 0, 0),
                Geo.box(0.004, 0.004, 0.18, mat(0x6D4C41)).at(-0.01, 0.09, 0).rot(0.3, 0, 0)
            )
        case .cake:
            r.add(
                Geo.cylinder(0.1, 0.06, mat(0xF06292, rough: 0.6), segments: 22).at(0, 0.03, 0),
                Geo.cylinder(0.07, 0.05, mat(0xFFF3F6, rough: 0.6), segments: 22).at(0, 0.085, 0)
            )
            for k in 0..<3 {
                let a = Float(k) / 3 * 2 * Float.pi
                r.add(
                    Geo.cylinder(0.006, 0.04, mat(0x64B5F6), segments: 6).at(cos(a) * 0.035, 0.13, sin(a) * 0.035),
                    Geo.sphere(0.009, MaterialCache.shared.pbr(0xFFCA28, emission: 0xFFB300, glow: 1.2), segments: 6).at(cos(a) * 0.035, 0.155, sin(a) * 0.035)
                )
            }
        }
        return r
    }
}

// MARK: - Stations

struct StationParts {
    let root: SCNNode
    var spin: SCNNode?
    var bob: SCNNode?
    var glow: SCNMaterial?
    var steamAt: SCNNode?
    var stockSlots: [SCNVector3]
}

enum StationFactory {
    static let appX: Float = -0.35
    static let top: Float = 0.93

    static func make(_ d: Dish, dishes: DishModels) -> StationParts {
        let root = SCNNode()
        let stat: [SCNNode] = [
            Geo.box(1.7, 0.86, 0.84, M.steel, chamfer: 0.02).at(0, 0.43, 0),
            Geo.box(1.74, 0.05, 0.9, M.steelDark, chamfer: 0.01).at(0, 0.885, 0),
            Geo.box(1.6, 0.04, 0.02, M.chrome).at(0, 0.7, 0.43),
            Geo.box(0.62, 0.02, 0.52, M.chrome).at(0.5, 0.92, 0.06),
        ]
        var parts = StationParts(root: root, spin: nil, bob: nil, glow: nil, steamAt: nil, stockSlots: [])
        for z in [Float(0.2), -0.07] {
            for x in [Float(0.32), 0.5, 0.68] { parts.stockSlots.append(SCNVector3(x, 0.935, z)) }
        }

        let app = SCNNode()
        app.name = "app"
        app.position = SCNVector3(appX, top, 0)
        var appStatic: [SCNNode] = []
        let glowMat = MaterialCache.shared.pbr(0xFF8A2A, rough: 0.4, emission: 0xFF7A1A, glow: 0.4).copy() as! SCNMaterial
        let cMat = { (h: UInt32) in MaterialCache.shared.pbr(h, rough: 0.5) }

        switch d.appliance {
        case .spit:
            appStatic += [
                Geo.box(0.5, 0.06, 0.45, M.steelDark).at(0, 0.03, 0),
                Geo.cylinder(0.018, 0.98, M.chrome, segments: 8).at(0, 0.52, 0),
                Geo.cylinder(0.07, 0.05, M.chrome, segments: 12).at(0, 0.98, 0),
                Geo.box(0.58, 0.8, 0.07, M.steelDark).at(0, 0.45, -0.3),
            ]
            let g = Geo.box(0.42, 0.62, 0.02, glowMat).at(0, 0.45, -0.258)
            app.addChildNode(g)
            parts.glow = glowMat
            let spin = SCNNode()
            spin.add(
                Geo.cone(0.11, 0.2, 0.64, cMat(d == .shawarmaXL ? 0xA0522D : 0x9C5A2E), segments: 14).at(0, 0.42, 0),
                Geo.cone(0.112, 0.19, 0.2, cMat(0x7A3E1C), segments: 14).at(0, 0.3, 0)
            )
            spin.position = SCNVector3(0, 0, 0)
            app.addChildNode(spin.flattenedClone())
            parts.spin = app.childNodes.last
        case .fryer:
            appStatic += [
                Geo.box(0.8, 0.32, 0.62, M.steel, chamfer: 0.02).at(0, 0.16, 0),
                Geo.box(0.7, 0.012, 0.5, MaterialCache.shared.pbr(0xD8A93B, rough: 0.12, metal: 0.2)).at(0, 0.32, 0),
            ]
            let bob = SCNNode()
            bob.add(
                Geo.box(0.3, 0.1, 0.36, M.steelDark).at(-0.17, 0.36, 0),
                Geo.box(0.3, 0.1, 0.36, M.steelDark).at(0.17, 0.36, 0),
                Geo.box(0.03, 0.03, 0.25, M.black).at(-0.17, 0.43, 0.25),
                Geo.box(0.03, 0.03, 0.25, M.black).at(0.17, 0.43, 0.25)
            )
            app.addChildNode(bob.flattenedClone())
            parts.bob = app.childNodes.last
            parts.steamAt = SCNNode().at(0, 0.4, 0)
        case .drinks:
            let front = MaterialCache.shared.pbr(d.hex, rough: 0.3, emission: d.hex, glow: 0.3).copy() as! SCNMaterial
            appStatic += [
                Geo.box(0.72, 0.82, 0.5, M.steelDark, chamfer: 0.03).at(0, 0.41, -0.02),
                Geo.box(0.72, 0.06, 0.32, M.steel).at(0, 0.03, 0.12),
                Geo.cylinder(0.025, 0.08, M.chrome, segments: 8).at(-0.2, 0.3, 0.2),
                Geo.cylinder(0.025, 0.08, M.chrome, segments: 8).at(0, 0.3, 0.2),
                Geo.cylinder(0.025, 0.08, M.chrome, segments: 8).at(0.2, 0.3, 0.2),
                Geo.cylinder(0.05, 0.3, M.white, segments: 12).at(0.48, 0.15, 0.1),
            ]
            app.addChildNode(Geo.box(0.6, 0.34, 0.02, front).at(0, 0.6, 0.235))
            parts.glow = front
        case .grill:
            appStatic += [
                Geo.box(0.86, 0.08, 0.62, M.black).at(0, 0.1, 0),
                Geo.box(0.86, 0.06, 0.06, M.steel).at(0, 0.03, 0.28),
                Geo.box(0.86, 0.42, 0.06, M.steel).at(0, 0.3, -0.3),
            ]
            for k in 0..<3 {
                appStatic.append(Geo.cylinder(0.075, 0.03, cMat(d == .steak ? 0x7B2E1E : 0x6D3B1E), segments: 14).at(-0.25 + Float(k) * 0.25, 0.155, 0.02))
            }
            app.addChildNode(Geo.box(0.8, 0.02, 0.55, glowMat).at(0, 0.055, 0))
            parts.glow = glowMat
            parts.steamAt = SCNNode().at(0, 0.2, 0)
        case .roller:
            appStatic.append(Geo.box(0.82, 0.12, 0.58, M.steel, chamfer: 0.02).at(0, 0.06, 0))
            for k in 0..<5 {
                let roll = Geo.cylinder(0.024, 0.72, M.chrome, segments: 10)
                roll.eulerAngles.z = Float.pi / 2
                appStatic.append(roll.at(0, 0.16, -0.18 + Float(k) * 0.09))
            }
            for k in 0..<3 {
                let s = Geo.cylinder(0.026, 0.5, cMat(0xB0472A), segments: 10)
                s.eulerAngles.z = Float.pi / 2
                appStatic.append(s.at(0, 0.205, -0.135 + Float(k) * 0.135))
            }
            app.addChildNode(Geo.box(0.74, 0.01, 0.5, glowMat).at(0, 0.125, 0))
            parts.glow = glowMat
        case .machine:
            let display = MaterialCache.shared.pbr(0x0D2B3A, rough: 0.2, emission: 0x41C7FF, glow: 0.4).copy() as! SCNMaterial
            appStatic += [
                Geo.box(0.56, 0.72, 0.46, cMat(d == .coffee ? 0x2B2B2B : 0x8D2B2B), chamfer: 0.04).at(0, 0.36, -0.04),
                Geo.box(0.56, 0.08, 0.2, M.steel).at(0, 0.04, 0.16),
                Geo.cylinder(0.03, 0.08, M.chrome, segments: 8).at(0, 0.42, 0.2),
                Geo.cylinder(0.045, 0.1, M.white, segments: 12).at(0, 0.13, 0.17),
            ]
            app.addChildNode(Geo.box(0.26, 0.12, 0.01, display).at(0, 0.6, 0.195))
            parts.glow = display
            parts.steamAt = SCNNode().at(0, 0.25, 0.17)
        case .oven:
            let dome = Geo.sphere(0.38, MaterialCache.shared.pbr(0xB5533C, rough: 0.9), segments: 18)
            dome.scale = SCNVector3(1, 0.8, 1)
            appStatic += [
                Geo.box(0.86, 0.14, 0.72, M.concrete).at(0, 0.07, 0),
                dome.at(0, 0.16, -0.02),
                Geo.box(0.34, 0.22, 0.12, M.black).at(0, 0.27, 0.3),
                Geo.cylinder(0.06, 0.32, M.steelDark, segments: 10).at(0.12, 0.6, -0.1),
            ]
            app.addChildNode(Geo.box(0.26, 0.15, 0.02, glowMat).at(0, 0.26, 0.365))
            parts.glow = glowMat
            parts.steamAt = SCNNode().at(0.12, 0.8, -0.1)
        case .blender:
            appStatic += [
                Geo.box(0.3, 0.16, 0.3, M.black, chamfer: 0.03).at(-0.15, 0.08, 0),
                Geo.box(0.3, 0.16, 0.3, M.black, chamfer: 0.03).at(0.25, 0.08, 0),
                Geo.cylinder(0.09, 0.26, MaterialCache.shared.pbr(d.hex, rough: 0.1, alpha: 0.8), segments: 14).at(0.25, 0.29, 0),
                Geo.cylinder(0.095, 0.03, M.black, segments: 14).at(0.25, 0.43, 0),
            ]
            let spin = SCNNode()
            spin.add(
                Geo.cylinder(0.1, 0.28, MaterialCache.shared.pbr(d.hex, rough: 0.1, alpha: 0.8), segments: 14).at(0, 0.3, 0),
                Geo.cylinder(0.105, 0.03, M.black, segments: 14).at(0, 0.455, 0),
                Geo.box(0.12, 0.02, 0.03, M.chrome).at(0, 0.2, 0)
            )
            let s = spin.flattenedClone()
            s.position = SCNVector3(-0.15, 0, 0)
            app.addChildNode(s)
            parts.spin = s
        case .display:
            appStatic += [
                Geo.box(0.86, 0.08, 0.58, M.steelDark).at(0, 0.04, 0),
                Geo.box(0.86, 0.03, 0.58, M.steelDark).at(0, 0.52, 0),
                Geo.box(0.84, 0.44, 0.56, M.glass).at(0, 0.3, 0),
            ]
            let spin = SCNNode()
            let plate = Geo.cylinder(0.22, 0.02, M.white, segments: 20)
            spin.addChildNode(plate)
            let item = dishes.node(d)
            item.scale = SCNVector3(1.6, 1.6, 1.6)
            item.position = SCNVector3(0, 0.01, 0)
            spin.addChildNode(item)
            spin.position = SCNVector3(0, 0.09, 0)
            app.addChildNode(spin)
            parts.spin = spin
            let light = MaterialCache.shared.pbr(0xFFF8E1, emission: 0xFFF3C4, glow: 0.5).copy() as! SCNMaterial
            app.addChildNode(Geo.box(0.8, 0.015, 0.04, light).at(0, 0.5, 0.2))
            parts.glow = light
        case .pot:
            appStatic += [
                Geo.tube(0.26, 0.3, 0.14, M.steelDark).at(0, 0.07, 0),
                Geo.cylinder(0.32, 0.26, MaterialCache.shared.pbr(0x2E2E2E, rough: 0.5, metal: 0.6), segments: 22).at(0, 0.27, 0),
            ]
            let lid = SCNNode()
            lid.add(
                Geo.cylinder(0.33, 0.03, MaterialCache.shared.pbr(0x3A3A3A, rough: 0.4, metal: 0.7), segments: 22).at(0, 0.42, 0),
                Geo.sphere(0.04, M.woodDark, segments: 8).at(0, 0.46, 0)
            )
            app.addChildNode(lid.flattenedClone())
            parts.bob = app.childNodes.last
            app.addChildNode(Geo.cylinder(0.24, 0.02, glowMat, segments: 16).at(0, 0.02, 0))
            parts.glow = glowMat
            parts.steamAt = SCNNode().at(0, 0.5, 0)
        }

        if !appStatic.isEmpty {
            let holder = SCNNode()
            for n in appStatic { holder.addChildNode(n) }
            app.addChildNode(merged(holder.childNodes))
        }
        if let s = parts.steamAt { app.addChildNode(s) }
        let base = merged(stat)
        root.addChildNode(base)
        root.addChildNode(app)
        return parts
    }

    /// Empty cabinet waiting to be unlocked.
    static func locked() -> SCNNode {
        merged([
            Geo.box(1.7, 0.86, 0.84, MaterialCache.shared.pbr(0x9EA4AA, rough: 0.6, metal: 0.3), chamfer: 0.02).at(0, 0.43, 0),
            Geo.box(1.74, 0.05, 0.9, M.steelDark).at(0, 0.885, 0),
            Geo.box(1.5, 0.5, 0.02, MaterialCache.shared.pbr(0xFFC94A, rough: 0.6)).at(0, 0.45, 0.43),
        ])
    }
}

// MARK: - Props

enum Props {
    static func tree(_ seed: Int, scale s: Float = 1) -> SCNNode {
        let leaf = seed % 2 == 0 ? M.leaves : M.leaves2
        let n = merged([
            Geo.cylinder(0.09, 1.1, M.trunk, segments: 7).at(0, 0.55, 0),
            Geo.node(Geo.blob(radius: 0.75, squash: 0.95, seed: seed), leaf).at(0, 1.55, 0),
            Geo.node(Geo.blob(radius: 0.5, squash: 0.9, seed: seed + 3), leaf).at(0.3, 1.95, 0.1),
        ])
        n.scale = SCNVector3(s, s, s)
        return n
    }

    static func planter(_ seed: Int) -> SCNNode {
        merged([
            Geo.box(1.0, 0.45, 1.0, M.concrete, chamfer: 0.04).at(0, 0.225, 0),
            Geo.cylinder(0.08, 1.0, M.trunk, segments: 7).at(0, 0.9, 0),
            Geo.node(Geo.blob(radius: 0.65, squash: 0.95, seed: seed), M.leaves).at(0, 1.6, 0),
        ])
    }

    static func lamp(halo: inout [SCNNode]) -> SCNNode {
        let n = SCNNode()
        n.addChildNode(merged([
            Geo.cylinder(0.12, 0.2, M.black, segments: 10).at(0, 0.1, 0),
            Geo.cylinder(0.05, 3.2, M.black, segments: 8).at(0, 1.6, 0),
            Geo.box(0.6, 0.06, 0.06, M.black).at(0.25, 3.15, 0),
            Geo.box(0.32, 0.1, 0.22, M.black).at(0.5, 3.1, 0),
            Geo.box(0.26, 0.04, 0.18, M.bulb).at(0.5, 3.04, 0),
        ]))
        let h = Geo.plane(2.4, 2.4, M.halo)
        h.position = SCNVector3(0.5, 3.0, 0)
        h.constraints = [SCNBillboardConstraint()]
        h.castsShadow = false
        h.renderingOrder = 20
        n.addChildNode(h)
        halo.append(h)
        return n
    }

    static func bench() -> SCNNode {
        merged([
            Geo.box(1.4, 0.06, 0.4, M.wood).at(0, 0.45, 0),
            Geo.box(1.4, 0.3, 0.05, M.wood).at(0, 0.65, -0.18).rot(-0.15, 0, 0),
            Geo.box(0.06, 0.45, 0.4, M.black).at(-0.6, 0.22, 0),
            Geo.box(0.06, 0.45, 0.4, M.black).at(0.6, 0.22, 0),
        ])
    }

    static func bin() -> SCNNode {
        merged([
            Geo.cylinder(0.22, 0.75, MaterialCache.shared.pbr(0x2E7D32, rough: 0.5, metal: 0.3), segments: 14).at(0, 0.375, 0),
            Geo.cylinder(0.24, 0.05, M.black, segments: 14).at(0, 0.77, 0),
        ])
    }

    static func pottedPlant(_ seed: Int) -> SCNNode {
        merged([
            Geo.cone(0.22, 0.16, 0.36, MaterialCache.shared.pbr(0xC0663A, rough: 0.8), segments: 12).at(0, 0.18, 0),
            Geo.node(Geo.blob(radius: 0.32, squash: 1.1, seed: seed), M.leaves2).at(0, 0.58, 0),
        ])
    }

    static func aFrame() -> SCNNode {
        let board = MaterialCache.shared.textured("chalk", Tex.chalkboard, rough: 0.9)
        return merged([
            Geo.plane(0.7, 0.9, board).at(0, 0.5, 0.17).rot(-0.32, 0, 0),
            Geo.plane(0.7, 0.9, board).at(0, 0.5, -0.17).rot(0.32, Float.pi, 0),
            Geo.box(0.04, 0.95, 0.04, M.woodDark).at(-0.36, 0.47, 0),
            Geo.box(0.04, 0.95, 0.04, M.woodDark).at(0.36, 0.47, 0),
        ])
    }

    static func tableSet(umbrella: Bool, accent: UInt32, accent2: UInt32) -> SCNNode {
        var parts: [SCNNode] = [
            Geo.cylinder(0.45, 0.05, M.white, segments: 20).at(0, 0.74, 0),
            Geo.cylinder(0.04, 0.72, M.black, segments: 8).at(0, 0.36, 0),
            Geo.cylinder(0.25, 0.03, M.black, segments: 12).at(0, 0.015, 0),
        ]
        for dz in [Float(-0.63), 0.63] {
            parts += [
                Geo.box(0.42, 0.05, 0.42, MaterialCache.shared.pbr(accent, rough: 0.5)).at(0, 0.46, dz),
                Geo.box(0.42, 0.4, 0.05, MaterialCache.shared.pbr(accent, rough: 0.5)).at(0, 0.68, dz + (dz > 0 ? 0.19 : -0.19)),
                Geo.box(0.04, 0.46, 0.04, M.black).at(-0.17, 0.23, dz - 0.17),
                Geo.box(0.04, 0.46, 0.04, M.black).at(0.17, 0.23, dz - 0.17),
                Geo.box(0.04, 0.46, 0.04, M.black).at(-0.17, 0.23, dz + 0.17),
                Geo.box(0.04, 0.46, 0.04, M.black).at(0.17, 0.23, dz + 0.17),
            ]
        }
        if umbrella {
            let canopy = MaterialCache.shared.textured("umb\(accent)", Tex.stripes(accent, accent2), rough: 0.8, repeatS: 2)
            parts += [
                Geo.cylinder(0.03, 1.6, M.white, segments: 8).at(0, 1.55, 0),
                Geo.cone(0.02, 1.25, 0.45, canopy, segments: 12).at(0, 2.25, 0),
            ]
        }
        return merged(parts)
    }

    static func car(_ kind: Int, color: UInt32) -> SCNNode {
        let body = MaterialCache.shared.pbr(color, rough: 0.3, metal: 0.4)
        let glass = MaterialCache.shared.pbr(0x2B3A48, rough: 0.1, metal: 0.3)
        var parts: [SCNNode] = []
        let length: CGFloat = kind == 2 ? 2.6 : 2.2
        let width: CGFloat = 1.05
        parts.append(Geo.box(length, 0.42, width, body, chamfer: 0.12).at(0, 0.42, 0))
        switch kind {
        case 2: // van
            parts.append(Geo.box(length * 0.78, 0.6, width * 0.96, body, chamfer: 0.1).at(-0.2, 0.9, 0))
            parts.append(Geo.box(0.05, 0.36, width * 0.86, glass).at(Float(length) * 0.19 + 0.02, 0.92, 0))
        default:
            parts.append(Geo.box(length * 0.55, 0.4, width * 0.9, glass, chamfer: 0.1).at(-0.1, 0.82, 0))
            parts.append(Geo.box(length * 0.5, 0.06, width * 0.92, body, chamfer: 0.03).at(-0.1, 1.03, 0))
            if kind == 1 {
                parts.append(Geo.box(0.36, 0.14, 0.2, MaterialCache.shared.pbr(0xFFFFFF, emission: 0xFFF59D, glow: 0.4)).at(-0.1, 1.13, 0))
            }
        }
        for sx in [Float(-1), 1] {
            for sz in [Float(-1), 1] {
                let w = Geo.cylinder(0.2, 0.16, M.black, segments: 14)
                w.eulerAngles.x = Float.pi / 2
                parts.append(w.at(sx * Float(length) * 0.32, 0.2, sz * Float(width) * 0.48))
            }
        }
        for sz in [Float(-0.32), 0.32] {
            parts.append(Geo.box(0.04, 0.1, 0.18, M.headlight).at(Float(length) / 2 + 0.005, 0.5, sz))
            parts.append(Geo.box(0.04, 0.1, 0.16, M.taillight).at(-Float(length) / 2 - 0.005, 0.5, sz))
        }
        return merged(parts)
    }

    /// Delivery scooter with its courier sitting on it (moving part handled by the renderer).
    static func scooter() -> SCNNode {
        let paint = MaterialCache.shared.pbr(0x43A047, rough: 0.35, metal: 0.3)
        let box = MaterialCache.shared.textured("delivery", Tex.deliveryBox, rough: 0.6)
        var parts: [SCNNode] = [
            Geo.box(0.95, 0.2, 0.32, paint, chamfer: 0.08).at(0, 0.35, 0),
            Geo.box(0.12, 0.6, 0.12, paint).at(0.42, 0.6, 0).rot(0, 0, -0.25),
            Geo.box(0.06, 0.06, 0.55, M.black).at(0.5, 0.92, 0),
            Geo.box(0.4, 0.1, 0.3, M.black, chamfer: 0.04).at(-0.12, 0.52, 0),
            Geo.box(0.5, 0.5, 0.5, box, chamfer: 0.03).at(-0.45, 0.85, 0),
            Geo.box(0.04, 0.08, 0.14, M.headlight).at(0.5, 0.75, 0),
        ]
        for x in [Float(-0.35), 0.4] {
            let w = Geo.cylinder(0.18, 0.1, M.black, segments: 14)
            w.eulerAngles.x = Float.pi / 2
            parts.append(w.at(x, 0.18, 0))
        }
        let n = merged(parts)
        return n
    }

    /// Giant rotating dish on the roof (decor level 9).
    static func statue(_ d: Dish, dishes: DishModels) -> SCNNode {
        let n = SCNNode()
        n.addChildNode(merged([
            Geo.cylinder(0.5, 0.3, M.gold, segments: 20).at(0, 0.15, 0),
            Geo.cylinder(0.08, 0.6, M.black, segments: 8).at(0, 0.6, 0),
        ]))
        let item = dishes.node(d)
        item.scale = SCNVector3(7, 7, 7)
        item.position = SCNVector3(0, 0.85, 0)
        let spinner = SCNNode()
        spinner.addChildNode(item)
        spinner.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 6)))
        n.addChildNode(spinner)
        return n
    }
}
