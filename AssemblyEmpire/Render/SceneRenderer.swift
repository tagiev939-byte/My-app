import SceneKit
import SpriteKit
import UIKit
import simd

// MARK: - Building view

final class BuildingView {
    let node: SCNNode
    let type: BuildingType
    private var spin: SCNNode?
    private var arm: SCNNode?
    private var glow: SCNMaterial?
    private var smoke: SCNParticleSystem?
    private var product: SCNNode?
    private var productType: ItemType?
    private var working: Bool?
    private(set) var dir: Dir
    let shape: BeltShape

    init(_ b: Building, lib: ModelLibrary, world: World, shape: BeltShape = .straight) {
        type = b.type
        dir = b.dir
        self.shape = shape
        node = b.type == .conveyor ? lib.conveyor(shape) : lib.building(b.type)
        node.name = "b:\(b.x):\(b.y)"
        node.position = SCNVector3(Float(b.x) + 0.5, 0, Float(b.y) + 0.5)
        if b.type.hasDirection { node.eulerAngles.y = b.dir.yaw }

        spin = node.childNode(withName: "spin", recursively: true)
        arm = node.childNode(withName: "arm", recursively: true)
        product = node.childNode(withName: "product", recursively: true)

        if let g = node.childNode(withName: "glow", recursively: true),
           let geo = g.geometry?.copy() as? SCNGeometry,
           let mat = geo.firstMaterial?.copy() as? SCNMaterial {
            geo.materials = [mat]
            g.geometry = geo
            glow = mat
        }

        if b.type == .smelter, let at = node.childNode(withName: "smokeAt", recursively: true) {
            let ps = Effects.smoke()
            at.addParticleSystem(ps)
            smoke = ps
        }

        if b.type == .drill {
            let res = world.resource(b.x, b.y)
            if res != .none {
                for k in 0..<4 {
                    let a = Float(k) * Float.pi / 2 + 0.6
                    let r = SCNNode(geometry: lib.rock(res, variant: k))
                    r.position = SCNVector3(cos(a) * 0.2, 0.09, sin(a) * 0.2)
                    r.scale = SCNVector3(0.55, 0.55, 0.55)
                    r.eulerAngles.y = a
                    node.addChildNode(r)
                }
            }
        }

        spin?.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 0.5)))
        spin?.isPaused = true
        if let arm {
            let swing = SCNAction.sequence([
                .rotateBy(x: 0, y: 1.7, z: 0, duration: 0.55),
                .wait(duration: 0.15),
                .rotateBy(x: 0, y: -1.7, z: 0, duration: 0.55),
                .wait(duration: 0.15),
            ])
            swing.timingMode = .easeInEaseOut
            arm.runAction(.repeatForever(swing))
            arm.isPaused = true
        }
        if let coin = node.childNode(withName: "coin", recursively: true) {
            coin.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 2.6)))
        }
        if b.type == .assembler { setProduct(b.recipe?.output, lib: lib) }

        node.enumerateHierarchy { n, _ in
            n.categoryBitMask = SceneRenderer.buildingMask
            n.castsShadow = true
        }
    }

    func setProduct(_ t: ItemType?, lib: ModelLibrary) {
        guard let product, t != productType else { return }
        productType = t
        product.childNodes.forEach { $0.removeFromParentNode() }
        guard let t else { return }
        let n = lib.item(t)
        n.scale = SCNVector3(1.1, 1.1, 1.1)
        n.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 4)))
        n.categoryBitMask = SceneRenderer.buildingMask
        product.addChildNode(n)
    }

    func setDir(_ d: Dir) {
        guard d != dir else { return }
        dir = d
        node.runAction(.rotateTo(x: 0, y: CGFloat(d.yaw), z: 0, duration: 0.18, usesShortestUnitArc: true))
    }

    func update(_ b: Building) {
        let w = b.working
        guard w != working else { return }
        working = w
        spin?.isPaused = !w
        arm?.isPaused = !w
        smoke?.birthRate = w ? 7 : 0
        if let glow {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.35
            switch type {
            case .smelter: glow.emission.intensity = w ? 2.4 : 0.25
            case .drill: glow.emission.intensity = w ? 2.0 : 0.1
            case .assembler: glow.emission.intensity = w ? 1.6 : 0.2
            default: break
            }
            SCNTransaction.commit()
        }
    }

    func pulse() {
        guard node.action(forKey: "pulse") == nil else { return }
        let up = SCNAction.scale(to: 1.08, duration: 0.08)
        up.timingMode = .easeOut
        let down = SCNAction.scale(to: 1.0, duration: 0.14)
        down.timingMode = .easeIn
        node.runAction(.sequence([up, down]), forKey: "pulse")
    }
}

// MARK: - Overlay (floating texts)

final class OverlayScene: SKScene {
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) { fatalError("not supported") }

    func floatText(_ text: String, at p: CGPoint, color: UIColor = UIColor(hex: 0xFFD54A), size fontSize: CGFloat = 17) {
        guard children.count < 50 else { return }
        let pos = CGPoint(x: p.x, y: size.height - p.y)
        let group = SKNode()
        group.position = pos
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.text = text
        shadow.fontSize = fontSize
        shadow.fontColor = UIColor(white: 0, alpha: 0.55)
        shadow.position = CGPoint(x: 1, y: -1.5)
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        group.addChild(shadow)
        group.addChild(label)
        group.setScale(0.5)
        addChild(group)
        let pop = SKAction.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1.0, duration: 0.1)])
        let rise = SKAction.moveBy(x: 0, y: 48, duration: 1.15)
        rise.timingMode = .easeOut
        let fade = SKAction.sequence([.wait(forDuration: 0.65), .fadeOut(withDuration: 0.5)])
        group.run(.sequence([.group([pop, rise, fade]), .removeFromParent()]))
    }
}

// MARK: - Renderer

final class SceneRenderer {
    static let buildingMask = 1 << 1

    let scene = SCNScene()
    let rig = CameraRig()
    let lib = ModelLibrary()
    let overlay = OverlayScene(size: CGSize(width: 390, height: 844))
    weak var view: SCNView?
    var highQuality = true {
        didSet { applyQuality() }
    }

    private let terrainRoot = SCNNode()
    private let decoRoot = SCNNode()
    private let buildingsRoot = SCNNode()
    private let itemsRoot = SCNNode()
    private let signsRoot = SCNNode()
    private let fxRoot = SCNNode()
    private let sun = SCNNode()
    private let selection = SCNNode()
    private let hint = SCNNode()

    private var chunkNodes: [SCNNode] = []
    private var chunkDeco: [SCNNode?] = Array(repeating: nil, count: World.chunks * World.chunks)
    private var views: [Int: BuildingView] = [:]
    private var items: [Int: ItemEntry] = [:]
    private var pools: [ItemType: [SCNNode]] = [:]
    private var signs: [Int: SCNNode] = [:]
    private var signPrices: [Int: Double] = [:]
    private var frameNo = 0
    private var beltPhase: Double = 0
    private var waterPhase: Float = 0
    private var waterMaterial = SCNMaterial()
    private var sideMaterial = SCNMaterial()
    private var isSetUp = false

    struct ItemEntry {
        let node: SCNNode
        let type: ItemType
        var frame: Int
    }

    // MARK: Setup

    func setup(_ world: World) {
        guard !isSetUp else {
            rebuild(world)
            return
        }
        isSetUp = true
        let root = scene.rootNode
        root.addChildNode(rig.root)
        [terrainRoot, decoRoot, buildingsRoot, itemsRoot, signsRoot, fxRoot, selection, hint].forEach { root.addChildNode($0) }

        // Sky, image based lighting and fog
        scene.background.contents = Tex.sky
        scene.lightingEnvironment.contents = Tex.sky
        scene.lightingEnvironment.intensity = 1.25
        scene.fogColor = Tex.horizon
        scene.fogStartDistance = 40
        scene.fogEndDistance = 120
        scene.fogDensityExponent = 1.4

        // Sun
        let light = SCNLight()
        light.type = .directional
        light.intensity = 1450
        light.color = UIColor(red: 1.0, green: 0.95, blue: 0.86, alpha: 1)
        light.castsShadow = true
        light.shadowMode = .deferred
        light.shadowColor = UIColor(white: 0, alpha: 0.55)
        light.shadowMapSize = CGSize(width: 2048, height: 2048)
        light.automaticallyAdjustsShadowProjection = true
        light.maximumShadowDistance = 55
        light.shadowCascadeCount = 2
        light.shadowRadius = 2.5
        sun.light = light
        sun.eulerAngles = SCNVector3(-0.92, 0.7, 0)
        root.addChildNode(sun)

        let ambient = SCNNode()
        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 180
        amb.color = UIColor(hex: 0xB8D4F0)
        ambient.light = amb
        root.addChildNode(ambient)

        // Water
        let water = SCNPlane(width: 360, height: 360)
        let wm = SCNMaterial()
        wm.lightingModel = .physicallyBased
        wm.diffuse.contents = UIColor(hex: 0x2B93CC)
        wm.roughness.contents = NSNumber(value: 0.1)
        wm.metalness.contents = NSNumber(value: 0.0)
        wm.normal.contents = Tex.waterNormal
        wm.normal.intensity = 0.8
        wm.normal.wrapS = .repeat
        wm.normal.wrapT = .repeat
        water.materials = [wm]
        waterMaterial = wm
        let waterNode = SCNNode(geometry: water)
        waterNode.eulerAngles.x = -Float.pi / 2
        waterNode.position = SCNVector3(25, -0.46, 25)
        waterNode.castsShadow = false
        root.addChildNode(waterNode)

        let shallow = SCNPlane(width: 72, height: 72)
        let sm = SCNMaterial()
        sm.lightingModel = .constant
        sm.diffuse.contents = Tex.shallow
        sm.blendMode = .alpha
        sm.writesToDepthBuffer = false
        shallow.materials = [sm]
        let shallowNode = SCNNode(geometry: shallow)
        shallowNode.eulerAngles.x = -Float.pi / 2
        shallowNode.position = SCNVector3(25, -0.44, 25)
        shallowNode.castsShadow = false
        root.addChildNode(shallowNode)

        // Beach
        let beach = Geo.box(51.6, 0.6, 51.6, MaterialCache.shared.pbr(0xE6D29B, rough: 0.95), chamfer: 0.45)
        beach.position = SCNVector3(25, -0.64, 25)
        beach.castsShadow = false
        root.addChildNode(beach)

        // Terrain chunk materials
        let side = SCNMaterial()
        side.lightingModel = .physicallyBased
        side.diffuse.contents = Tex.cliff
        side.diffuse.wrapS = .repeat
        side.diffuse.contentsTransform = SCNMatrix4MakeScale(10, 1, 1)
        side.roughness.contents = NSNumber(value: 0.95)
        sideMaterial = side

        buildSelection()
        buildHint()
        build(world)
        applyQuality()
    }

    private func applyQuality() {
        let cam = rig.camera
        cam.wantsHDR = true
        cam.wantsExposureAdaptation = false
        cam.exposureOffset = 0
        cam.bloomIntensity = highQuality ? 0.45 : 0.25
        cam.bloomThreshold = 0.85
        cam.bloomBlurRadius = 6
        cam.screenSpaceAmbientOcclusionIntensity = highQuality ? 0.7 : 0
        cam.screenSpaceAmbientOcclusionRadius = 0.35
        cam.screenSpaceAmbientOcclusionNormalThreshold = 0.3
        cam.screenSpaceAmbientOcclusionDepthThreshold = 0.25
        cam.saturation = 1.0
        cam.contrast = 0.08
        cam.vignettingIntensity = 0.35
        cam.vignettingPower = 0.6
        sun.light?.shadowSampleCount = highQuality ? 8 : 2
        sun.light?.shadowMapSize = highQuality ? CGSize(width: 2048, height: 2048) : CGSize(width: 1024, height: 1024)
        view?.antialiasingMode = highQuality ? .multisampling4X : .multisampling2X
    }

    private func build(_ world: World) {
        for c in 0..<(World.chunks * World.chunks) {
            let box = SCNBox(width: 10, height: 1.2, length: 10, chamferRadius: 0)
            box.materials = [sideMaterial, sideMaterial, sideMaterial, sideMaterial, MaterialCache.shared.pbr(0x78AE55, rough: 0.95), sideMaterial]
            let n = SCNNode(geometry: box)
            let top = SCNNode(geometry: Geo.beltQuad(width: 10, length: 10))
            top.geometry?.materials = [topMaterial(world, c)]
            top.position = SCNVector3(0, 0.603, 0)
            top.name = "top"
            top.castsShadow = false
            n.addChildNode(top)
            let cx = c % World.chunks, cy = c / World.chunks
            n.position = SCNVector3(Float(cx * 10) + 5, chunkTop(world.owned[c]) - 0.6, Float(cy * 10) + 5)
            n.castsShadow = false
            terrainRoot.addChildNode(n)
            chunkNodes.append(n)
        }
        for c in 0..<(World.chunks * World.chunks) { rebuildDeco(c, world) }
        for b in world.buildings {
            guard let b else { continue }
            addBuilding(b, world, animated: false)
        }
        refreshAllShapes(world)
        updateSigns(world)
    }

    /// Compile shaders for every model up front so nothing pops in later.
    func prewarm() {
        guard let v = view else { return }
        var nodes: [SCNNode] = BuildingType.allCases.map { lib.building($0) }
        nodes += ItemType.allCases.map { lib.item($0) }
        nodes += [lib.conveyor(.left), lib.conveyor(.right)]
        v.prepare(nodes, completionHandler: nil)
    }

    func rebuild(_ world: World) {
        chunkNodes.forEach { $0.removeFromParentNode() }
        chunkNodes.removeAll()
        chunkDeco.forEach { $0?.removeFromParentNode() }
        chunkDeco = Array(repeating: nil, count: World.chunks * World.chunks)
        views.values.forEach { $0.node.removeFromParentNode() }
        views.removeAll()
        items.values.forEach { $0.node.removeFromParentNode() }
        items.removeAll()
        pools.values.forEach { $0.forEach { $0.removeFromParentNode() } }
        pools.removeAll()
        signs.values.forEach { $0.removeFromParentNode() }
        signs.removeAll()
        signPrices.removeAll()
        setSelection(nil)
        setHint(nil)
        build(world)
    }

    private func chunkTop(_ owned: Bool) -> Float { owned ? 0 : -0.14 }

    private func topMaterial(_ world: World, _ c: Int) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = Tex.ground(world, chunk: c, owned: world.owned[c])
        m.diffuse.mipFilter = .linear
        m.roughness.contents = NSNumber(value: 0.92)
        m.metalness.contents = NSNumber(value: 0.0)
        return m
    }

    // MARK: Decorations

    func rebuildDeco(_ c: Int, _ world: World) {
        chunkDeco[c]?.removeFromParentNode()
        chunkDeco[c] = nil
        let container = SCNNode()
        let owned = world.owned[c]
        let baseY = chunkTop(owned)
        let cx = c % World.chunks, cy = c / World.chunks
        for y in (cy * World.chunk)..<((cy + 1) * World.chunk) {
            for x in (cx * World.chunk)..<((cx + 1) * World.chunk) {
                if world.buildings[world.index(x, y)] != nil { continue }
                let res = world.resource(x, y)
                if res != .none {
                    let count = res == .quartz ? 3 : 3
                    for k in 0..<count {
                        let hx = Float(tileHash(x, y, 40 + k, world.seed))
                        let hz = Float(tileHash(x, y, 50 + k, world.seed))
                        let hs = Float(tileHash(x, y, 60 + k, world.seed))
                        let n = SCNNode(geometry: lib.rock(res, variant: Int(hs * 4)))
                        let s: Float = res == .quartz ? (0.7 + hs * 0.6) : (0.6 + hs * 0.7)
                        n.scale = SCNVector3(s, s, s)
                        n.position = SCNVector3(Float(x) + 0.2 + hx * 0.6, baseY + (res == .quartz ? 0 : 0.03), Float(y) + 0.2 + hz * 0.6)
                        n.eulerAngles = SCNVector3(res == .quartz ? (hx - 0.5) * 0.5 : 0, hs * 6.28, res == .quartz ? (hz - 0.5) * 0.5 : 0)
                        container.addChildNode(n)
                    }
                } else {
                    let h = tileHash(x, y, 7, world.seed)
                    let density = owned ? 0.05 : 0.3
                    if h < density {
                        let v = Int(tileHash(x, y, 8, world.seed) * 4)
                        let t = lib.tree(variant: v)
                        let s = Float(0.75 + tileHash(x, y, 9, world.seed) * 0.6)
                        t.scale = SCNVector3(s, s, s)
                        t.position = SCNVector3(Float(x) + 0.5 + Float(tileHash(x, y, 11, world.seed) - 0.5) * 0.4,
                                                baseY,
                                                Float(y) + 0.5 + Float(tileHash(x, y, 12, world.seed) - 0.5) * 0.4)
                        t.eulerAngles.y = Float(h * 40)
                        container.addChildNode(t)
                    }
                }
            }
        }
        guard !container.childNodes.isEmpty else { return }
        let flat = container.flattenedClone()
        flat.castsShadow = true
        decoRoot.addChildNode(flat)
        chunkDeco[c] = flat
    }

    func refreshDeco(at p: TilePos, _ world: World) {
        rebuildDeco(world.chunkOf(p.x, p.y), world)
    }

    // MARK: Buildings

    func addBuilding(_ b: Building, _ world: World, animated: Bool) {
        let idx = world.index(b.x, b.y)
        views[idx]?.node.removeFromParentNode()
        let shape: BeltShape = b.type == .conveyor ? beltShape(b, world) : .straight
        let v = BuildingView(b, lib: lib, world: world, shape: shape)
        views[idx] = v
        buildingsRoot.addChildNode(v.node)
        if animated { refreshShapes(around: b.pos, world) }
        if animated {
            v.node.scale = SCNVector3(0.3, 0.3, 0.3)
            let up = SCNAction.scale(to: 1.1, duration: 0.14)
            up.timingMode = .easeOut
            let down = SCNAction.scale(to: 1.0, duration: 0.12)
            down.timingMode = .easeInEaseOut
            v.node.runAction(.sequence([up, down]))
            if b.type != .conveyor { burst(Effects.dust(), at: SIMD3(Float(b.x) + 0.5, 0.05, Float(b.y) + 0.5)) }
        }
    }

    func removeBuilding(at p: TilePos, _ world: World, animated: Bool) {
        let idx = world.index(p.x, p.y)
        guard let v = views.removeValue(forKey: idx) else { return }
        if animated {
            v.node.enumerateHierarchy { n, _ in n.categoryBitMask = 0 }
            let shrink = SCNAction.scale(to: 0.05, duration: 0.18)
            shrink.timingMode = .easeIn
            v.node.runAction(.sequence([shrink, .removeFromParentNode()]))
            burst(Effects.dust(), at: SIMD3(Float(p.x) + 0.5, 0.05, Float(p.y) + 0.5))
        } else {
            v.node.removeFromParentNode()
        }
        refreshShapes(around: p, world)
    }

    func refreshBuilding(_ b: Building, _ world: World) {
        guard let v = views[world.index(b.x, b.y)] else { return }
        if b.type.hasDirection { v.setDir(b.dir) }
        if b.type == .assembler { v.setProduct(b.recipe?.output, lib: lib) }
        refreshShapes(around: b.pos, world)
    }

    // MARK: Belt shapes

    func beltShape(_ b: Building, _ world: World) -> BeltShape {
        func feeds(_ side: Dir) -> Bool {
            guard let n = world.building(b.x + side.dx, b.y + side.dy) else { return false }
            let toward = side.opposite
            switch n.type {
            case .conveyor, .drill, .smelter, .assembler: return n.dir == toward
            case .splitter: return n.dir == toward || n.dir.cw == toward || n.dir.ccw == toward
            case .junction: return side == b.dir.opposite
            case .market: return false
            }
        }
        if feeds(b.dir.opposite) { return .straight }
        let l = feeds(b.dir.ccw), r = feeds(b.dir.cw)
        if l && !r { return .left }
        if r && !l { return .right }
        return .straight
    }

    func refreshShapes(around p: TilePos, _ world: World) {
        for t in [p, p.moved(.up), p.moved(.down), p.moved(.left), p.moved(.right)] {
            guard let b = world.building(t.x, t.y), b.type == .conveyor else { continue }
            let idx = world.index(t.x, t.y)
            guard let old = views[idx] else { continue }
            let shape = beltShape(b, world)
            if shape == old.shape && old.dir == b.dir { continue }
            let v = BuildingView(b, lib: lib, world: world, shape: shape)
            old.node.removeAllActions()
            old.node.removeFromParentNode()
            v.node.scale = old.node.scale
            if v.node.scale.x < 1 { v.node.runAction(.scale(to: 1, duration: 0.15)) }
            views[idx] = v
            buildingsRoot.addChildNode(v.node)
        }
    }

    func refreshAllShapes(_ world: World) {
        for (idx, v) in views where v.type == .conveyor {
            guard let b = world.buildings[idx] else { continue }
            let shape = beltShape(b, world)
            if shape != v.shape { refreshShapes(around: b.pos, world) }
        }
    }

    func upgradeEffect(_ b: Building, _ world: World) {
        views[world.index(b.x, b.y)]?.pulse()
        burst(Effects.sparkle(), at: SIMD3(Float(b.x) + 0.5, 0.6, Float(b.y) + 0.5))
    }

    func burst(_ ps: SCNParticleSystem, at p: SIMD3<Float>) {
        let n = SCNNode()
        n.simdPosition = p
        n.addParticleSystem(ps)
        fxRoot.addChildNode(n)
        n.runAction(.sequence([.wait(duration: 2.0), .removeFromParentNode()]))
    }

    // MARK: Land

    func chunkPurchased(_ c: Int, _ world: World) {
        let n = chunkNodes[c]
        n.childNode(withName: "top", recursively: false)?.geometry?.materials = [topMaterial(world, c)]
        let move = SCNAction.move(to: SCNVector3(n.position.x, chunkTop(true) - 0.6, n.position.z), duration: 0.6)
        move.timingMode = .easeOut
        n.runAction(move)
        rebuildDeco(c, world)
        if let d = chunkDeco[c] {
            d.position.y = -0.14
            let up = SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.6)
            up.timingMode = .easeOut
            d.runAction(up)
        }
        let cx = c % World.chunks, cy = c / World.chunks
        for k in 0..<5 {
            let x = Float(cx * 10) + 1 + Float(k) * 2
            burst(Effects.sparkle(), at: SIMD3(x, 0.4, Float(cy * 10) + 5))
        }
        updateSigns(world)
    }

    func updateSigns(_ world: World) {
        let price = world.landCost
        for c in 0..<(World.chunks * World.chunks) {
            if world.canBuyChunk(c) {
                if signPrices[c] == price, signs[c] != nil { continue }
                signs[c]?.removeFromParentNode()
                let s = makeSign(Fmt.money(price))
                let cx = c % World.chunks, cy = c / World.chunks
                s.position = SCNVector3(Float(cx * 10) + 5, chunkTop(false), Float(cy * 10) + 5)
                signsRoot.addChildNode(s)
                signs[c] = s
                signPrices[c] = price
            } else if let s = signs.removeValue(forKey: c) {
                s.removeFromParentNode()
                signPrices[c] = nil
            }
        }
    }

    private func makeSign(_ price: String) -> SCNNode {
        let root = SCNNode()
        root.addChildNode(Geo.cylinder(0.07, 1.3, M.woodDark, segments: 8).at(0, 0.65, 0))
        let board = SCNBox(width: 2.4, height: 1.5, length: 0.08, chamferRadius: 0.06)
        let face = SCNMaterial()
        face.lightingModel = .physicallyBased
        face.diffuse.contents = Tex.sign(price: price)
        face.emission.contents = Tex.sign(price: price)
        face.emission.intensity = 0.35
        face.roughness.contents = NSNumber(value: 0.7)
        board.materials = [face, M.wood, M.wood, M.wood, M.wood, M.wood]
        let bn = SCNNode(geometry: board)
        bn.position = SCNVector3(0, 1.85, 0)
        let holder = SCNNode()
        holder.addChildNode(bn)
        let bb = SCNBillboardConstraint()
        bb.freeAxes = .Y
        holder.constraints = [bb]
        root.addChildNode(holder)
        let bob = SCNAction.sequence([.moveBy(x: 0, y: 0.12, z: 0, duration: 1.2), .moveBy(x: 0, y: -0.12, z: 0, duration: 1.2)])
        bob.timingMode = .easeInEaseOut
        bn.runAction(.repeatForever(bob))
        return root
    }

    // MARK: Selection & hints

    private func buildSelection() {
        let m = M.highlight
        let t: CGFloat = 0.06, l: CGFloat = 1.06
        selection.add(
            Geo.box(l, 0.03, t, m).at(0, 0, -0.5),
            Geo.box(l, 0.03, t, m).at(0, 0, 0.5),
            Geo.box(t, 0.03, l, m).at(-0.5, 0, 0),
            Geo.box(t, 0.03, l, m).at(0.5, 0, 0)
        )
        selection.isHidden = true
        selection.castsShadow = false
        let pulse = SCNAction.sequence([.fadeOpacity(to: 0.35, duration: 0.5), .fadeOpacity(to: 1, duration: 0.5)])
        selection.runAction(.repeatForever(pulse))
    }

    private func buildHint() {
        let m = M.highlight
        let arrow = SCNNode()
        arrow.add(
            Geo.cone(0.24, 0, 0.36, m, segments: 16).at(0, 0, 0),
            Geo.cylinder(0.09, 0.4, m, segments: 12).at(0, 0.38, 0)
        )
        arrow.position = SCNVector3(0, 1.25, 0)
        let bob = SCNAction.sequence([.moveBy(x: 0, y: 0.35, z: 0, duration: 0.45), .moveBy(x: 0, y: -0.35, z: 0, duration: 0.45)])
        bob.timingMode = .easeInEaseOut
        arrow.runAction(.repeatForever(bob))
        hint.addChildNode(arrow)
        let t: CGFloat = 0.08, l: CGFloat = 1.1
        let ring = SCNNode()
        ring.add(
            Geo.box(l, 0.04, t, m).at(0, 0, -0.52),
            Geo.box(l, 0.04, t, m).at(0, 0, 0.52),
            Geo.box(t, 0.04, l, m).at(-0.52, 0, 0),
            Geo.box(t, 0.04, l, m).at(0.52, 0, 0)
        )
        ring.position = SCNVector3(0, 0.03, 0)
        ring.runAction(.repeatForever(.sequence([.fadeOpacity(to: 0.3, duration: 0.45), .fadeOpacity(to: 1, duration: 0.45)])))
        hint.addChildNode(ring)
        hint.isHidden = true
        hint.enumerateHierarchy { n, _ in n.castsShadow = false }
    }

    func setSelection(_ p: TilePos?) {
        guard let p else {
            selection.isHidden = true
            return
        }
        selection.isHidden = false
        selection.position = SCNVector3(Float(p.x) + 0.5, 0.02, Float(p.y) + 0.5)
    }

    func setHint(_ p: TilePos?) {
        guard let p else {
            hint.isHidden = true
            return
        }
        hint.isHidden = false
        hint.position = SCNVector3(Float(p.x) + 0.5, 0, Float(p.y) + 0.5)
    }

    // MARK: Per-frame update

    func update(_ world: World, dt: Double) {
        rig.update(dt)

        beltPhase = (beltPhase + world.beltSpeed * dt).truncatingRemainder(dividingBy: 1)
        lib.beltMaterial.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0, Float(beltPhase), 0)

        waterPhase += Float(dt) * 0.012
        if waterPhase > 1 { waterPhase -= 1 }
        waterMaterial.normal.contentsTransform = SCNMatrix4Mult(SCNMatrix4MakeScale(36, 36, 1),
                                                                SCNMatrix4MakeTranslation(waterPhase, waterPhase * 0.6, 0))

        for (idx, v) in views {
            if let b = world.buildings[idx] { v.update(b) }
        }
        syncItems(world)
    }

    private func syncItems(_ world: World) {
        frameNo &+= 1
        let f = frameNo
        for case let b? in world.buildings {
            switch b.type {
            case .conveyor:
                for c in b.lane { placeItem(c, b, y: 0.094, exit: b.dir, f) }
            case .splitter:
                for c in b.lane { placeItem(c, b, y: 0.18, exit: c.to ?? b.dir, f) }
            case .junction:
                for c in b.lane { placeItem(c, b, y: 0.165, exit: c.from.opposite, f) }
                for c in b.cross { placeItem(c, b, y: 0.165, exit: c.from.opposite, f) }
            default:
                continue
            }
        }
        var stale: [Int] = []
        for (id, e) in items where e.frame != f { stale.append(id) }
        for id in stale {
            if let e = items.removeValue(forKey: id) {
                e.node.isHidden = true
                pools[e.type, default: []].append(e.node)
            }
        }
    }

    private func placeItem(_ c: Cargo, _ b: Building, y: Float, exit: Dir, _ f: Int) {
        let node: SCNNode
        if var e = items[c.id] {
            e.frame = f
            items[c.id] = e
            node = e.node
        } else {
            if var list = pools[c.type], let n = list.popLast() {
                pools[c.type] = list
                node = n
                node.isHidden = false
            } else {
                node = lib.item(c.type)
                itemsRoot.addChildNode(node)
            }
            items[c.id] = ItemEntry(node: node, type: c.type, frame: f)
        }
        let cx = Float(b.x) + 0.5, cz = Float(b.y) + 0.5
        let entry = SIMD3<Float>(cx + Float(c.from.dx) * 0.5, y, cz + Float(c.from.dy) * 0.5)
        let center = SIMD3<Float>(cx, y, cz)
        let out = SIMD3<Float>(cx + Float(exit.dx) * 0.5, y, cz + Float(exit.dy) * 0.5)
        let p = Float(min(1, max(0, c.p)))
        let pos: SIMD3<Float>
        let yaw: Float
        if b.type == .conveyor {
            let q = 1 - p
            pos = entry * (q * q) + center * (2 * q * p) + out * (p * p)
            let tan = (center - entry) * (2 * q) + (out - center) * (2 * p)
            yaw = atan2(-tan.x, -tan.z)
        } else if p < 0.5 {
            pos = simd_mix(entry, center, SIMD3<Float>(repeating: p * 2))
            yaw = c.from.opposite.yaw
        } else {
            pos = simd_mix(center, out, SIMD3<Float>(repeating: (p - 0.5) * 2))
            yaw = exit.yaw
        }
        node.simdPosition = pos
        node.simdEulerAngles = SIMD3(0, yaw, 0)
    }

    // MARK: Picking & popups

    func viewSize() -> CGSize { view?.bounds.size ?? CGSize(width: 390, height: 844) }

    func ground(_ p: CGPoint) -> SIMD3<Float>? {
        rig.ground(p, viewSize: viewSize())
    }

    func groundTile(_ p: CGPoint) -> TilePos? {
        guard let g = ground(p) else { return nil }
        return TilePos(Int(floor(g.x)), Int(floor(g.z)))
    }

    func pick(_ p: CGPoint) -> TilePos? {
        if let v = view {
            let hits = v.hitTest(p, options: [
                SCNHitTestOption.categoryBitMask: SceneRenderer.buildingMask,
                SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue,
            ])
            for h in hits {
                var n: SCNNode? = h.node
                while let cur = n {
                    if let name = cur.name, name.hasPrefix("b:") {
                        let parts = name.split(separator: ":")
                        if parts.count == 3, let x = Int(parts[1]), let y = Int(parts[2]) { return TilePos(x, y) }
                    }
                    n = cur.parent
                }
            }
        }
        return groundTile(p)
    }

    func panCamera(from a: CGPoint, to b: CGPoint) {
        guard let g0 = ground(a), let g1 = ground(b) else { return }
        rig.pan(by: g0 - g1)
    }

    func zoomCamera(scale: CGFloat, around p: CGPoint) {
        let g0 = ground(p)
        rig.zoom(scale: Float(scale))
        if let g0, let g1 = ground(p) { rig.pan(by: g0 - g1) }
    }

    func cashPopup(x: Int, y: Int, amount: Double, world: World) {
        views[world.index(x, y)]?.pulse()
        guard let v = view else { return }
        let p = v.projectPoint(SCNVector3(Float(x) + 0.5, 1.25, Float(y) + 0.5))
        guard p.z > 0, p.z < 1 else { return }
        let pt = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        guard v.bounds.insetBy(dx: -40, dy: -40).contains(pt) else { return }
        overlay.floatText(Fmt.gain(amount), at: pt)
        if rig.distance < 22 { burst(Effects.coins(), at: SIMD3(Float(x) + 0.5, 1.1, Float(y) + 0.5)) }
    }

    func screenPoint(of p: TilePos, height: Float = 0) -> CGPoint? {
        guard let v = view else { return nil }
        let s = v.projectPoint(SCNVector3(Float(p.x) + 0.5, height, Float(p.y) + 0.5))
        guard s.z > 0, s.z < 1 else { return nil }
        return CGPoint(x: CGFloat(s.x), y: CGFloat(s.y))
    }
}
