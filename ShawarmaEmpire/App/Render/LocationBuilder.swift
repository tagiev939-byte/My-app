import SceneKit
import UIKit
import simd

/// A material whose emission follows the day/night cycle.
struct NightMaterial {
    let material: SCNMaterial
    let day: CGFloat
    let night: CGFloat
}

struct EnvBuild {
    let root: SCNNode
    var halos: [SCNNode] = []
    var night: [NightMaterial] = []
    var menu: SCNMaterial
    var water: SCNMaterial?
}

/// Builds the static street scene around a restaurant.
enum LocationBuilder {
    static func build(_ info: LocationInfo) -> EnvBuild {
        let t = info.theme
        let root = SCNNode()
        var casters: [SCNNode] = []
        var ground: [SCNNode] = []
        var halos: [SCNNode] = []
        var night: [NightMaterial] = []
        let c = MaterialCache.shared

        // Ground, street and pavement
        let groundMat = t.backdrop == .city || t.backdrop == .mall ? M.concrete : M.grass
        if t.backdrop == .river {
            // The city ends at the embankment; the river lies below.
            ground.append(Geo.box(90, 0.1, 52, groundMat).at(0, -0.06, 19.4))
            ground.append(Geo.box(90, 0.8, 0.3, M.concrete).at(0, -0.45, -6.75))
        } else {
            ground.append(Geo.box(90, 0.1, 90, groundMat).at(0, -0.06, 0))
        }
        let walk = c.textured("sidewalk", Tex.sidewalk, rough: 0.95, repeatS: 16, repeatT: 2.6)
        ground.append(Geo.box(34, 0.08, 5.2, walk).at(0, 0.04, 4.1))
        ground.append(Geo.box(34, 0.08, 2.0, walk).at(0, 0.04, 0.5))
        ground.append(Geo.box(34, 0.12, 0.16, M.concrete).at(0, 0.06, 6.62))
        let road = c.textured("road", Tex.road, rough: 0.9, repeatS: 8, repeatT: 1)
        ground.append(Geo.box(34, 0.02, 3.6, road).at(0, 0.01, 8.5))
        ground.append(Geo.box(34, 0.12, 0.16, M.concrete).at(0, 0.06, 10.38))
        ground.append(Geo.box(34, 0.08, 1.6, walk).at(0, 0.04, 11.2))
        ground.append(Geo.box(34, 0.08, 4.0, walk).at(0, 0.04, -4.6))

        // Restaurant shell
        let floor = c.textured("floor\(info.id)", Tex.tiles(t.floorA, t.floorB), rough: 0.5, repeatS: 4.3, repeatT: 2.2)
        ground.append(Geo.box(8.6, 0.12, 4.4, floor).at(0, 0.06, -0.7))
        let wallMat: SCNMaterial
        switch t.backdrop {
        case .university: wallMat = c.textured("brick", Tex.brick, rough: 0.9, repeatS: 4, repeatT: 2)
        case .river: wallMat = c.textured("planks", Tex.planks, rough: 0.85, repeatS: 3, repeatT: 2)
        default: wallMat = c.pbr(t.wall, rough: 0.8)
        }
        let trim = c.pbr(t.trim, rough: 0.6, metal: t.backdrop == .city ? 0.8 : 0.1)
        casters += [
            Geo.box(8.8, 3.4, 0.3, wallMat).at(0, 1.7, -3.0),
            Geo.box(0.3, 2.4, 4.3, wallMat).at(-4.35, 1.2, -0.85),
            Geo.box(0.3, 2.4, 4.3, wallMat).at(4.35, 1.2, -0.85),
            Geo.box(9.0, 0.16, 0.4, trim).at(0, 3.45, -3.0),
            Geo.box(0.4, 0.14, 4.4, trim).at(-4.35, 2.45, -0.85),
            Geo.box(0.4, 0.14, 4.4, trim).at(4.35, 2.45, -0.85),
            Geo.box(0.32, 3.0, 0.32, trim).at(-4.35, 1.5, 1.4),
            Geo.box(0.32, 3.0, 0.32, trim).at(4.35, 1.5, 1.4),
        ]
        // Wall shelves with jars
        for side in [Float(-1), 1] {
            casters.append(Geo.box(1.4, 0.05, 0.3, M.woodDark).at(side * 3.2, 2.1, -2.72))
            for k in 0..<4 {
                let jar = c.pbr([0xE57373, 0xFFD54F, 0x81C784, 0x64B5F6][k], rough: 0.3)
                casters.append(Geo.cylinder(0.08, 0.2, jar, segments: 10).at(side * 3.2 - 0.5 + Float(k) * 0.33, 2.23, -2.72))
            }
        }
        // Awning
        let stripes = c.textured("awning\(info.id)", Tex.stripes(t.accent, t.accent2), rough: 0.8, repeatS: 6)
        casters.append(Geo.box(9.1, 0.06, 0.8, stripes).at(0, 3.2, 1.72).rot(0.3, 0, 0))
        casters.append(Geo.box(9.1, 0.2, 0.04, stripes).at(0, 3.0, 2.11))

        // Counter
        let counterMat = c.pbr(t.counter, rough: 0.5, metal: t.backdrop == .city ? 0.4 : 0.05)
        let topMat = t.backdrop == .city ? M.gold : c.pbr(0xEDE6DA, rough: 0.35)
        casters += [
            Geo.box(7.9, 0.62, 0.5, counterMat, chamfer: 0.03).at(0, 0.43, 1.2),
            Geo.box(8.05, 0.07, 0.66, topMat, chamfer: 0.02).at(0, 0.775, 1.2),
            Geo.box(7.92, 0.08, 0.02, c.pbr(t.accent2, rough: 0.5)).at(0, 0.56, 1.46),
        ]

        // Sign on the roof and menu board
        let signImg = Tex.sign(info.sign, bg: t.accent, fg: t.signColor)
        let signMat = SCNMaterial()
        signMat.lightingModel = .physicallyBased
        signMat.diffuse.contents = signImg
        signMat.emission.contents = signImg
        signMat.emission.intensity = 0.5
        signMat.roughness.contents = NSNumber(value: 0.5)
        let sign = SCNBox(width: 6.2, height: 1.36, length: 0.24, chamferRadius: 0.06)
        sign.materials = [signMat, trim, trim, trim, trim, trim]
        casters.append(SCNNode(geometry: sign).at(0, 4.15, -2.98))
        night.append(NightMaterial(material: signMat, day: 0.35, night: 1.6))

        let menuMat = SCNMaterial()
        menuMat.lightingModel = .physicallyBased
        menuMat.diffuse.contents = Tex.menuBoard(info.dishes, icons: [:], prices: [])
        menuMat.emission.contents = menuMat.diffuse.contents
        menuMat.emission.intensity = 0.15
        menuMat.roughness.contents = NSNumber(value: 0.6)
        let menuNode = Geo.plane(3.3, 1.65, menuMat)
        menuNode.position = SCNVector3(0, 2.5, -2.84)
        root.addChildNode(menuNode)

        // Neighbour shops framing the restaurant
        let shutter = c.textured("shutter", Tex.shutter, rough: 0.6, metal: 0.3, repeatS: 2, repeatT: 1)
        for side in [Float(-1), 1] {
            let wall = c.pbr(side < 0 ? 0xD7CCC8 : 0xCFD8DC, rough: 0.85)
            let awn = c.textured("nawn\(Int(side))", Tex.stripes(side < 0 ? 0x5C6BC0 : 0x8D6E63, 0xFAFAFA), rough: 0.8, repeatS: 3)
            casters += [
                Geo.box(5.2, 3.6, 4.4, wall).at(side * 7.4, 1.8, -1.0),
                Geo.plane(3.6, 2.0, shutter).at(side * 7.4, 1.08, 1.21),
                Geo.box(4.2, 0.06, 0.8, awn).at(side * 7.4, 2.5, 1.55).rot(0.32, 0, 0),
                Geo.box(5.4, 0.2, 4.6, c.pbr(0x8D8D8D, rough: 0.7)).at(side * 7.4, 3.65, -1.0),
            ]
        }

        // Street furniture
        for x in [Float(-9.6), 9.6] {
            let lamp = Props.lamp(halo: &halos)
            lamp.position = SCNVector3(x, 0.08, 6.25)
            lamp.eulerAngles.y = x < 0 ? 0 : Float.pi
            root.addChildNode(lamp)
        }
        for x in [Float(-12.5), 12.5] {
            casters.append(Props.planter(Int(x) + info.id).at(x, 0.08, 3.4))
        }
        casters.append(Props.bench().at(-10.6, 0.08, 1.7))
        casters.append(Props.bin().at(10.3, 0.08, 1.9))
        for k in 0..<9 {
            let x = -16 + Float(k) * 4
            casters.append(Geo.node(Geo.blob(radius: 0.7, squash: 0.6, seed: k + 50), M.leaves).at(x, 0.15, 12.6))
        }
        casters.append(Props.tree(11, scale: 1.2).at(-14, 0, 13.4))
        casters.append(Props.tree(12, scale: 1.1).at(14, 0, 13.6))

        // Backdrop behind the restaurant
        var water: SCNMaterial?
        switch t.backdrop {
        case .metro:
            let (d, e) = Tex.facade(wall: 0xD8D2C4, window: 0x4A6A86, cols: 6, rows: 9, seed: 3)
            let fac = c.textured("facadeMetro", d, rough: 0.85, emission: e)
            night.append(NightMaterial(material: fac, day: 0, night: 1.3))
            casters += [
                Geo.box(10, 13, 7, fac).at(-11, 6.5, -11),
                Geo.box(10, 15, 7, fac).at(1, 7.5, -13.5),
                Geo.box(10, 11, 7, fac).at(12.5, 5.5, -11),
            ]
            let mSign = c.textured("metroM", Tex.metroSign(), rough: 0.4, emission: Tex.metroSign())
            night.append(NightMaterial(material: mSign, day: 0.6, night: 1.8))
            casters += [
                Geo.box(4.2, 2.6, 3.0, c.pbr(0xB0BEC5, rough: 0.3, metal: 0.5)).at(8.2, 1.3, -5.5),
                Geo.box(4.4, 0.2, 3.2, M.red).at(8.2, 2.7, -5.5),
                Geo.box(2.0, 2.0, 0.05, M.black).at(8.2, 1.0, -3.98),
                Geo.cylinder(0.06, 3.2, M.black, segments: 8).at(5.6, 1.6, -4.2),
                Geo.box(0.9, 0.9, 0.1, mSign).at(5.6, 3.5, -4.2),
            ]
            casters.append(Props.tree(21, scale: 1.3).at(-7.5, 0, -6))
            casters.append(Props.tree(22, scale: 1.1).at(-3.5, 0, -6.8))
        case .university:
            let (d, e) = Tex.facade(wall: 0xEFE3C8, window: 0x5D7A94, cols: 12, rows: 3, seed: 8)
            let fac = c.textured("facadeUni", d, rough: 0.85, emission: e)
            night.append(NightMaterial(material: fac, day: 0, night: 1.1))
            let cream = c.pbr(0xF2E8D0, rough: 0.8)
            casters += [
                Geo.box(26, 8, 7, fac).at(0, 4, -12),
                Geo.box(11, 0.6, 3.4, cream).at(0, 6.9, -7.4),
                Geo.node(Geo.gable(width: 11, height: 2.2, depth: 3.4), cream).at(0, 7.2, -7.4),
                Geo.box(11, 0.3, 3.6, cream).at(0, 0.15, -7.3),
                Geo.box(10.6, 0.3, 3.0, cream).at(0, 0.45, -7.6),
            ]
            for k in 0..<6 {
                casters.append(Geo.cylinder(0.32, 6.0, cream, segments: 14).at(-4.5 + Float(k) * 1.8, 3.6, -6.2))
            }
            casters.append(Props.tree(31, scale: 1.4).at(-9, 0, -6))
            casters.append(Props.tree(32, scale: 1.3).at(9, 0, -6))
            for k in 0..<5 {
                let bike = c.pbr([0xE53935, 0x1E88E5, 0x43A047, 0xFDD835, 0x212121][k], rough: 0.4, metal: 0.4)
                casters.append(Geo.box(0.05, 0.5, 1.2, bike).at(-12 + Float(k) * 0.5, 0.35, -4.2))
            }
        case .mall:
            let (d, e) = Tex.facade(wall: 0x90A4AE, window: 0x4FC3F7, cols: 10, rows: 6, seed: 12, glassy: true)
            let fac = c.textured("facadeMall", d, rough: 0.15, metal: 0.5, emission: e)
            night.append(NightMaterial(material: fac, day: 0.05, night: 1.0))
            let logo = Tex.sign("ГАЛЕРЕЯ", bg: 0x5E35B1, fg: 0xFFFFFF)
            let logoMat = c.textured("mallLogo", logo, rough: 0.4, emission: logo)
            night.append(NightMaterial(material: logoMat, day: 0.5, night: 1.6))
            casters += [
                Geo.box(30, 10, 9, fac).at(0, 5, -13),
                Geo.box(12, 0.3, 3.5, c.pbr(0xECEFF1, rough: 0.4, metal: 0.3)).at(0, 4.2, -7.3),
                Geo.box(9, 1.6, 0.2, logoMat).at(0, 8.6, -8.4),
            ]
            for x in [Float(-6), -3, 3, 6] {
                casters.append(Geo.cylinder(0.05, 6, M.chrome, segments: 8).at(x, 3, -5.6))
                casters.append(Geo.box(0.05, 1.2, 0.8, c.pbr(x < 0 ? 0x7E57C2 : 0xFFB300, rough: 0.6)).at(x, 5.3, -5.2))
            }
        case .river:
            let wm = SCNMaterial()
            wm.lightingModel = .physicallyBased
            wm.diffuse.contents = UIColor(hex: 0x2F7FA8)
            wm.roughness.contents = NSNumber(value: 0.08)
            wm.metalness.contents = NSNumber(value: 0.0)
            wm.normal.contents = Tex.waterNormal
            wm.normal.wrapS = .repeat
            wm.normal.wrapT = .repeat
            wm.normal.intensity = 0.7
            water = wm
            let w = Geo.floor(120, 50, wm)
            w.position = SCNVector3(0, -0.35, -31)
            w.castsShadow = false
            root.addChildNode(w)
            casters.append(Geo.box(34, 0.5, 0.4, M.concrete).at(0, -0.05, -6.6))
            for k in 0..<18 {
                casters.append(Geo.cylinder(0.04, 1.0, M.black, segments: 6).at(-17 + Float(k) * 2, 0.55, -6.5))
            }
            casters.append(Geo.box(34, 0.06, 0.06, M.black).at(0, 1.05, -6.5))
            let (d, e) = Tex.facade(wall: 0xBCAAA4, window: 0x546E7A, cols: 5, rows: 4, seed: 21)
            let fac = c.textured("facadeRiver", d, rough: 0.85, emission: e)
            night.append(NightMaterial(material: fac, day: 0, night: 1.4))
            for k in 0..<7 {
                let h = 5 + Float(k % 3) * 2.5
                casters.append(Geo.box(7, CGFloat(h), 6, fac).at(-24 + Float(k) * 8, h / 2 - 0.3, -52))
            }
            for x in stride(from: Float(-15), through: 15, by: 0.9) {
                let sag = 0.25 * sin((x + 15) / 30 * Float.pi * 6)
                casters.append(Geo.sphere(0.07, M.bulb, segments: 6).at(x, 2.6 - abs(sag), -6.3))
            }
            casters.append(Geo.box(34, 0.02, 0.02, M.black).at(0, 2.68, -6.3))
            for x in stride(from: Float(-15), through: 15, by: 5) {
                casters.append(Geo.cylinder(0.05, 2.7, M.black, segments: 6).at(x, 1.35, -6.3))
            }
        case .city:
            let (d, e) = Tex.facade(wall: 0x37474F, window: 0x90CAF9, cols: 6, rows: 18, seed: 31, glassy: true)
            let fac = c.textured("facadeCity", d, rough: 0.12, metal: 0.6, emission: e)
            night.append(NightMaterial(material: fac, day: 0.05, night: 1.2))
            let heights: [Float] = [22, 34, 18, 28, 40, 24]
            for (k, h) in heights.enumerated() {
                let x = -20 + Float(k) * 8
                let z: Float = k % 2 == 0 ? -14 : -20
                casters.append(Geo.box(7, CGFloat(h), 7, fac).at(x, h / 2, z))
                casters.append(Geo.box(7.4, 0.4, 7.4, c.pbr(0x263238, rough: 0.5, metal: 0.5)).at(x, h + 0.2, z))
            }
            casters.append(Geo.cylinder(2.4, 0.1, c.pbr(0x455A64, rough: 0.6), segments: 24).at(12, 40.5, -20))
            casters.append(Props.planter(41).at(-8, 0.08, -5.5))
            casters.append(Props.planter(42).at(8, 0.08, -5.5))
        }

        let groundNode = merged(ground, shadows: false)
        root.addChildNode(groundNode)
        root.addChildNode(merged(casters))
        night.append(NightMaterial(material: M.bulb, day: 0.2, night: 2.6))
        return EnvBuild(root: root, halos: halos, night: night, menu: menuMat, water: water)
    }

    // MARK: Decor

    /// Decor props unlocked level by level.
    static func decor(level: Int, info: LocationInfo, dishes: DishModels, night: inout [NightMaterial]) -> SCNNode {
        let t = info.theme
        let root = SCNNode()
        var parts: [SCNNode] = []
        if level >= 1 {
            parts.append(Props.pottedPlant(1).at(-4.75, 0.08, 1.9))
            parts.append(Props.pottedPlant(2).at(4.75, 0.08, 1.9))
        }
        if level >= 2 { parts.append(Props.aFrame().at(-5.3, 0.08, 4.85).rot(0, 0.5, 0)) }
        if level >= 3 { parts.append(Props.tableSet(umbrella: level >= 8, accent: t.accent, accent2: t.accent2).at(Layout.tables[0].x, 0.08, Layout.tables[0].y)) }
        if level >= 4 { parts.append(Props.tableSet(umbrella: level >= 8, accent: t.accent, accent2: t.accent2).at(Layout.tables[1].x, 0.08, Layout.tables[1].y)) }
        if level >= 5 {
            for x in stride(from: Float(-4.3), through: 4.3, by: 0.43) {
                let sag = 0.12 * abs(sin(x * 0.73))
                parts.append(Geo.sphere(0.06, M.bulb, segments: 6).at(x, 2.55 - sag, 2.12))
            }
        }
        if level >= 6 {
            let neon = MaterialCache.shared.pbr(t.signColor, rough: 0.3, emission: t.signColor, glow: 1.0)
            night.append(NightMaterial(material: neon, day: 0.6, night: 2.4))
            parts += [
                Geo.box(6.6, 0.07, 0.07, neon).at(0, 4.88, -2.84),
                Geo.box(6.6, 0.07, 0.07, neon).at(0, 3.42, -2.84),
                Geo.box(0.07, 1.5, 0.07, neon).at(-3.3, 4.15, -2.84),
                Geo.box(0.07, 1.5, 0.07, neon).at(3.3, 4.15, -2.84),
            ]
        }
        if level >= 7 {
            for x in [Float(-3.6), -1.2, 1.2, 3.6] {
                parts.append(Geo.box(0.7, 0.32, 0.28, MaterialCache.shared.pbr(0x8D6E63, rough: 0.8)).at(x, 0.24, 1.68))
                for k in 0..<4 {
                    let col: UInt32 = [0xEC407A, 0xFFEB3B, 0xAB47BC, 0xFF7043][(k + Int(x * 3)) & 3]
                    parts.append(Geo.sphere(0.08, MaterialCache.shared.pbr(col, rough: 0.6), segments: 6).at(x - 0.24 + Float(k) * 0.16, 0.44, 1.68 + Float(k % 2) * 0.06 - 0.03))
                }
            }
        }
        if level >= 10 {
            parts.append(Geo.box(1.1, 0.012, 3.4, MaterialCache.shared.pbr(0xB71C1C, rough: 0.9)).at(0, 0.088, 3.4))
            for z in [Float(1.9), 3.4, 4.9] {
                for x in [Float(-0.75), 0.75] {
                    parts.append(Geo.cylinder(0.05, 0.9, M.gold, segments: 10).at(x, 0.53, z))
                    parts.append(Geo.sphere(0.08, M.gold, segments: 10).at(x, 1.0, z))
                }
            }
            for x in [Float(-0.75), 0.75] {
                parts.append(Geo.box(0.04, 0.04, 3.0, MaterialCache.shared.pbr(0xB71C1C, rough: 0.6)).at(x, 0.85, 3.4))
            }
        }
        if !parts.isEmpty { root.addChildNode(merged(parts)) }
        if level >= 9 {
            let s = Props.statue(info.dishes[0], dishes: dishes)
            s.position = SCNVector3(0, 4.85, -2.98)
            root.addChildNode(s)
        }
        return root
    }
}
