import SceneKit
import UIKit
import simd

enum Pick: Equatable {
    case station(Int), locked(Int), counter, courier, gift
}

// MARK: - Station view

final class StationView {
    let index: Int
    let dish: Dish
    let open: Bool
    let node = SCNNode()
    private(set) var parts: StationParts?
    private(set) var cooks: [PersonView] = []
    private let stockNode = SCNNode()
    private var stockSlots: [SCNVector3] = []
    private weak var dishModels: DishModels?
    /// Merged trays of 0...6 portions, shared by all stations cooking the same dish (1 draw call each).
    private static var stackCache: [Dish: [Int: SCNGeometry]] = [:]
    private var steam: SCNParticleSystem?
    private var barFill: SCNNode?
    private var barMat: SCNMaterial?
    private var barHolder: SCNNode?
    private var shownStock = -1
    private var glowValue: CGFloat = 0.3
    private var steamValue: CGFloat = 0
    private let phase = Float.random(in: 0...6)
    var signNode: SCNNode?

    init(index j: Int, dish: Dish, open: Bool, cooks: Int, loc: Int, dishes: DishModels, sign: UIImage?) {
        index = j
        self.dish = dish
        self.open = open
        node.position = SCNVector3(Layout.stationX[j], 0.12, Layout.stationZ)
        node.name = open ? "st:\(j)" : "lock:\(j)"

        if open {
            let p = StationFactory.make(dish, dishes: dishes)
            node.addChildNode(p.root)
            parts = p
            stockSlots = p.stockSlots
            dishModels = dishes
            stockNode.castsShadow = false
            p.root.addChildNode(stockNode)
            if let at = p.steamAt {
                let ps = Effects.steam()
                at.addParticleSystem(ps)
                steam = ps
            }
            for k in 0..<cooks {
                let cook = PersonView(role: .cook, look: j * 7 + k * 3 + loc * 13 + 1)
                cook.root.position = SCNVector3(k == 0 ? StationFactory.appX : 0.5, 0, 0.8)
                node.addChildNode(cook.root)
                self.cooks.append(cook)
            }
            // Cooking progress bar
            let holder = SCNNode()
            holder.position = SCNVector3(0, 1.95, 0)
            holder.constraints = [SCNBillboardConstraint()]
            let bg = SCNMaterial()
            bg.lightingModel = .constant
            bg.diffuse.contents = UIColor(white: 0.08, alpha: 0.75)
            bg.blendMode = .alpha
            bg.readsFromDepthBuffer = false
            bg.writesToDepthBuffer = false
            let back = Geo.plane(0.86, 0.1, bg)
            back.renderingOrder = 60
            holder.addChildNode(back)
            let fm = SCNMaterial()
            fm.lightingModel = .constant
            fm.diffuse.contents = UIColor(hex: 0xFFB74D)
            fm.readsFromDepthBuffer = false
            fm.writesToDepthBuffer = false
            let fill = Geo.plane(0.8, 0.06, fm)
            fill.pivot = SCNMatrix4MakeTranslation(-0.4, 0, 0)
            fill.position = SCNVector3(-0.4, 0, 0.001)
            fill.renderingOrder = 61
            holder.addChildNode(fill)
            holder.castsShadow = false
            node.addChildNode(holder)
            barHolder = holder
            barFill = fill
            barMat = fm
        } else {
            node.addChildNode(StationFactory.locked())
            if let sign {
                let m = SCNMaterial()
                m.lightingModel = .constant
                m.diffuse.contents = sign
                m.isDoubleSided = true
                let plane = Geo.plane(1.05, 1.05, m)
                plane.castsShadow = false
                let holder = SCNNode()
                holder.position = SCNVector3(0, 1.75, 0.1)
                let bb = SCNBillboardConstraint()
                bb.freeAxes = .Y
                holder.constraints = [bb]
                holder.addChildNode(plane)
                let bob = SCNAction.sequence([.moveBy(x: 0, y: 0.12, z: 0, duration: 1.1), .moveBy(x: 0, y: -0.12, z: 0, duration: 1.1)])
                bob.timingMode = .easeInEaseOut
                plane.runAction(.repeatForever(bob))
                node.addChildNode(holder)
                signNode = holder
            }
        }

        // Generous invisible pick volume
        let pickMat = SCNMaterial()
        pickMat.colorBufferWriteMask = []
        pickMat.writesToDepthBuffer = false
        let pick = Geo.box(1.9, 2.3, 1.7, pickMat).at(0, 1.15, 0.35)
        pick.castsShadow = false
        pick.isHidden = true
        node.addChildNode(pick)
        node.enumerateHierarchy { n, _ in n.categoryBitMask |= SceneRenderer.pickMask }
    }

    func update(_ st: StationState, working w: Bool, rate: Double, time: Double, dt: Double) {
        guard let p = parts else { return }
        let t = Float(time) + phase
        let fdt = Float(dt)
        switch dish.appliance {
        case .spit:
            p.spin?.eulerAngles.y += fdt * (w ? 1.8 : 0.35)
        case .blender:
            if let s = p.spin {
                s.eulerAngles.y += fdt * (w ? 22 : 0)
                s.position.y = w ? sin(t * 40) * 0.006 : 0
            }
        case .display:
            p.spin?.eulerAngles.y += fdt * 0.7
        case .fryer:
            if let b = p.bob {
                let target: Float = w ? -0.075 + sin(t * 4) * 0.012 : 0
                b.position.y += (target - b.position.y) * min(1, fdt * 6)
            }
        case .pot:
            if let b = p.bob {
                b.position.y = w ? max(0, sin(t * 15)) * 0.018 : 0
                b.eulerAngles.z = w ? sin(t * 9) * 0.04 : 0
            }
        default:
            break
        }
        if let glow = p.glow {
            let target: CGFloat
            switch dish.appliance {
            case .spit, .grill, .roller, .oven, .pot:
                target = w ? CGFloat(1.5 + 0.35 * sin(t * 8.7) + 0.15 * sin(t * 23.1)) : 0.22
            default:
                target = w ? 0.95 : 0.3
            }
            glowValue += (target - glowValue) * CGFloat(min(1, dt * 8))
            glow.emission.intensity = glowValue
        }
        if let steam {
            let target: CGFloat = w ? 9 : 0
            steamValue += (target - steamValue) * CGFloat(min(1, dt * 3))
            steam.birthRate = steamValue < 0.3 ? 0 : steamValue
        }
        for c in cooks { c.work(time: time, active: w, dt: fdt) }

        let n = min(st.stock, stockSlots.count)
        if n != shownStock {
            stockNode.geometry = stack(n)
            if n > shownStock && shownStock >= 0 && stockNode.action(forKey: "pop") == nil {
                let up = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 0.08)
                up.timingMode = .easeOut
                let down = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 0.12)
                down.timingMode = .easeIn
                stockNode.runAction(.sequence([up, down]), forKey: "pop")
            }
            shownStock = n
        }

        if let fill = barFill, let holder = barHolder {
            let full = st.stock >= Rules.capacity(st.level)
            let busy = st.cooks > 0 || st.progress > 0
            holder.isHidden = !busy && !full
            let f: Float = full ? 1 : (rate > 2.5 ? 1 : Float(min(1, max(0.02, st.progress))))
            fill.scale = SCNVector3(f, 1, 1)
            barMat?.diffuse.contents = full ? UIColor(hex: 0x66BB6A) : UIColor(hex: rate > 2.5 ? 0xFFD54F : 0xFFB74D)
        }
    }

    private func stack(_ n: Int) -> SCNGeometry? {
        guard n > 0, let dishes = dishModels else { return nil }
        if let g = StationView.stackCache[dish]?[n] { return g }
        let items = (0..<n).map { k -> SCNNode in
            let it = dishes.node(dish)
            it.position = stockSlots[k]
            return it
        }
        let g = merged(items, shadows: false).geometry
        if let g { StationView.stackCache[dish, default: [:]][n] = g }
        return g
    }

    func pulse() {
        guard let app = parts?.root.childNode(withName: "app", recursively: false), app.action(forKey: "pulse") == nil else { return }
        let up = SCNAction.scale(to: 1.12, duration: 0.07)
        up.timingMode = .easeOut
        let down = SCNAction.scale(to: 1.0, duration: 0.18)
        down.timingMode = .easeInEaseOut
        app.runAction(.sequence([up, down]), forKey: "pulse")
    }

    /// World position of the tray where cooked food is stacked.
    var trayWorld: SIMD3<Float> {
        SIMD3(Layout.stationX[index] + 0.5, 1.1, Layout.stationZ + 0.06)
    }

    var applianceWorld: SIMD3<Float> {
        SIMD3(Layout.stationX[index] + StationFactory.appX, 1.45, Layout.stationZ)
    }
}

// MARK: - Customer view

final class CustomerView {
    let id: Int
    let person: PersonView
    var frame = 0
    private var bubble: SCNNode?
    private var bubblePlane: SCNNode?
    private var bubbleMat: SCNMaterial?
    private var bubbleKey = ""
    private var bar: SCNNode?
    private var barMat: SCNMaterial?
    private var mood: SCNNode?
    private var moodKind: Mood = .none
    private var badge: SCNNode?
    private var sitting = false
    private var umbrella = false

    init(_ c: Customer, loc: Int) {
        id = c.id
        person = PersonView(role: c.vip ? .vip : .customer(location: loc), look: c.look)
    }

    private static let barBack: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = UIColor(white: 0.1, alpha: 0.7)
        m.blendMode = .alpha
        m.readsFromDepthBuffer = false
        m.writesToDepthBuffer = false
        return m
    }()

    private static func bubbleMaterial(_ img: UIImage) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = img
        m.isDoubleSided = true
        m.readsFromDepthBuffer = false
        m.writesToDepthBuffer = false
        return m
    }

    private static let heartMat = bubbleMaterial(Tex.heartBubble)
    private static let angryMat = bubbleMaterial(Tex.angryBubble)
    private static let vipMat = bubbleMaterial(Tex.vipBadge)

    func update(_ c: Customer, dt: Float, raining: Bool, icons: [String: UIImage], scale k: Float, time: Double) {
        let r = person.root
        r.position = SCNVector3(c.pos.x, 0.08, c.pos.y)
        r.eulerAngles.y = c.yaw
        let sit = c.state == .sitting
        if sit != sitting {
            sitting = sit
            person.sit(sit)
        }
        if !sit { person.animate(moving: c.moving, speed: c.speed, dt: dt) }
        person.setBag(c.bag)
        let wantUmbrella = raining && !sit
        if wantUmbrella != umbrella {
            umbrella = wantUmbrella
            person.setUmbrella(wantUmbrella, look: c.look)
        }

        // Order bubble with patience bar for the customer at the head of a queue.
        let showOrder = c.waiting && c.window >= 0 && c.slot == 0 && !c.order.isEmpty
        if showOrder {
            let key = c.order.map { $0.rawValue }.joined(separator: ",") + "|\(c.collected.count)|\(c.vip)|\(icons.count)"
            if bubble == nil {
                let holder = SCNNode()
                holder.constraints = [SCNBillboardConstraint()]
                holder.castsShadow = false
                r.addChildNode(holder)
                bubble = holder
                holder.scale = SCNVector3(0.1, 0.1, 0.1)
                let pop = SCNAction.scale(to: 1, duration: 0.22)
                pop.timingMode = .easeOut
                holder.runAction(pop, forKey: "pop")
            }
            if key != bubbleKey, let holder = bubble {
                bubbleKey = key
                let img = Tex.orderBubble(c.order, collected: c.collected.count, vip: c.vip, icons: icons)
                let h: CGFloat = 0.8
                let w = h * img.size.width / max(1, img.size.height)
                bubblePlane?.removeFromParentNode()
                bar?.parent?.removeFromParentNode()
                let m = CustomerView.bubbleMaterial(img)
                let plane = Geo.plane(w, h, m)
                plane.renderingOrder = 80
                plane.castsShadow = false
                holder.addChildNode(plane)
                bubblePlane = plane
                bubbleMat = m
                // patience bar on top of the bubble
                let barRoot = SCNNode()
                barRoot.position = SCNVector3(0, Float(h) / 2 + 0.07, 0)
                let back = Geo.plane(0.62, 0.075, CustomerView.barBack)
                back.renderingOrder = 81
                barRoot.addChildNode(back)
                let fm = SCNMaterial()
                fm.lightingModel = .constant
                fm.diffuse.contents = UIColor(hex: 0x4CAF50)
                fm.readsFromDepthBuffer = false
                fm.writesToDepthBuffer = false
                let fill = Geo.plane(0.58, 0.045, fm)
                fill.pivot = SCNMatrix4MakeTranslation(-0.29, 0, 0)
                fill.position = SCNVector3(-0.29, 0, 0.001)
                fill.renderingOrder = 82
                barRoot.addChildNode(fill)
                holder.addChildNode(barRoot)
                bar = fill
                barMat = fm
            }
            if let holder = bubble {
                if holder.action(forKey: "pop") == nil { holder.scale = SCNVector3(k, k, k) }
                holder.position = SCNVector3(0, 1.6 + 0.55 * k, 0)
                let f = Float(max(0, min(1, c.patience / c.maxPatience)))
                bar?.scale = SCNVector3(max(0.02, f), 1, 1)
                let col: UInt32 = f > 0.5 ? 0x4CAF50 : (f > 0.25 ? 0xFFB300 : 0xE53935)
                barMat?.diffuse.contents = UIColor(hex: col)
                if f < 0.25 {
                    bubblePlane?.eulerAngles.z = sin(Float(time) * 30) * 0.06
                } else {
                    bubblePlane?.eulerAngles.z = 0
                }
            }
        } else if let b = bubble {
            bubble = nil
            bubblePlane = nil
            bar = nil
            bubbleKey = ""
            b.removeAllActions()
            b.runAction(.sequence([.scale(to: 0.05, duration: 0.12), .removeFromParentNode()]))
        }

        // Mood
        if c.mood != moodKind {
            moodKind = c.mood
            mood?.removeFromParentNode()
            mood = nil
            if c.mood != .none {
                let m = c.mood == .happy ? CustomerView.heartMat : CustomerView.angryMat
                let plane = Geo.plane(0.48, 0.48, m)
                plane.renderingOrder = 85
                plane.castsShadow = false
                let holder = SCNNode()
                holder.constraints = [SCNBillboardConstraint()]
                holder.position = SCNVector3(0, 1.75, 0)
                holder.addChildNode(plane)
                holder.scale = SCNVector3(0.1, 0.1, 0.1)
                let pop = SCNAction.sequence([.scale(to: 1.2 * CGFloat(k), duration: 0.14), .scale(to: CGFloat(k), duration: 0.1)])
                holder.runAction(pop)
                plane.runAction(.moveBy(x: 0, y: 0.5, z: 0, duration: 1.6))
                r.addChildNode(holder)
                mood = holder
            }
        }

        // VIP crown
        let wantBadge = c.vip && c.state != .passing && !showOrder
        if wantBadge, badge == nil {
            let plane = Geo.plane(0.42, 0.32, CustomerView.vipMat)
            plane.renderingOrder = 84
            plane.castsShadow = false
            let holder = SCNNode()
            holder.constraints = [SCNBillboardConstraint()]
            holder.position = SCNVector3(0, 1.72, 0)
            holder.addChildNode(plane)
            let bob = SCNAction.sequence([.moveBy(x: 0, y: 0.08, z: 0, duration: 0.5), .moveBy(x: 0, y: -0.08, z: 0, duration: 0.5)])
            bob.timingMode = .easeInEaseOut
            plane.runAction(.repeatForever(bob))
            r.addChildNode(holder)
            badge = holder
        } else if !wantBadge, let b = badge {
            b.removeFromParentNode()
            badge = nil
        }
    }
}

// MARK: - Cars

final class CarView {
    let node: SCNNode
    let dir: Float
    let z: Float
    var x: Float
    var speed: Float
    var wait: Double

    init(kind: Int, color: UInt32, dir: Float, z: Float, x: Float, beam: SCNMaterial) {
        let car = Props.car(kind, color: color)
        let holder = SCNNode()
        holder.addChildNode(car)
        let length: Float = kind == 2 ? 2.6 : 2.2
        let b = Geo.floor(3.2, 1.4, beam)
        b.position = SCNVector3(length / 2 + 1.6, 0.035, 0)
        b.castsShadow = false
        b.renderingOrder = 10
        holder.addChildNode(b)
        if dir < 0 { holder.eulerAngles.y = Float.pi }
        node = holder
        self.dir = dir
        self.z = z
        self.x = x
        speed = Float.random(in: 3.2...5.2)
        wait = 0
        node.position = SCNVector3(x, 0.02, z)
    }
}

// MARK: - Renderer

final class SceneRenderer {
    static let pickMask = 1 << 2

    let scene = SCNScene()
    let rig = CameraRig()
    let dishes = DishModels()
    weak var view: SCNView?
    var icons: [String: UIImage] = [:]
    var highQuality = true {
        didSet { applyQuality() }
    }

    private(set) var loc = -1
    private(set) var time: Double = 0

    private let envRoot = SCNNode()
    private let dynRoot = SCNNode()
    private let peopleRoot = SCNNode()
    private let carsRoot = SCNNode()
    private let fxRoot = SCNNode()
    private let giftRoot = SCNNode()
    private var gift: SCNNode?
    private var giftX: Float = 0
    private var giftDir: Float = 1
    private var flicker: Double = 0
    private var flickerCooldown: Double = 6
    private let sun = SCNNode()
    private let ambient = SCNNode()
    private let shopLight = SCNNode()
    private let selection = SCNNode()
    private let hint = SCNNode()
    private let rainNode = SCNNode()
    private var rainPS: SCNParticleSystem?
    private var splashPS: SCNParticleSystem?

    private var envCache: [Int: EnvBuild] = [:]
    private var env: EnvBuild?
    private var stations: [StationView?] = [nil, nil, nil, nil]
    private var stationKeys = ["", "", "", ""]
    private var cashiers: [PersonView] = []
    private var serveT: [Double] = [0, 0, 0]
    private var windowNodes: [SCNNode] = []
    private var windowsShown = -1
    private var decorNode: SCNNode?
    private var decorShown = -1
    private var decorNight: [NightMaterial] = []
    private var menuKey = ""
    private var customers: [Int: CustomerView] = [:]
    private var frameNo = 0
    private var cars: [CarView] = []
    private var courier: SCNNode?
    private var courierPerson: PersonView?
    private var courierBubble: SCNNode?
    private var courierKey = ""
    private var flyers: [Flyer] = []
    private var lastNight: Double = -1
    private var rainLevel: Double = 0
    private var skyKey = -1
    private var waterPhase: Float = 0
    private let beamMat: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = Tex.beam
        m.multiply.contents = UIColor(hex: 0xFFE2A8)
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.transparency = 0
        return m
    }()
    private let highlight: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = UIColor(hex: 0xFFD54A)
        m.writesToDepthBuffer = false
        return m
    }()

    struct Flyer {
        let node: SCNNode
        let from: SIMD3<Float>
        let to: SIMD3<Float>
        let start: Double
        let duration: Double
        let arc: Float
    }

    // MARK: Setup

    func setup() {
        let root = scene.rootNode
        root.addChildNode(rig.root)
        [envRoot, dynRoot, peopleRoot, carsRoot, fxRoot, giftRoot, selection, hint, rainNode].forEach { root.addChildNode($0) }

        scene.background.contents = Tex.skyImage(0, rain: 0)
        scene.lightingEnvironment.contents = Tex.sky
        scene.lightingEnvironment.intensity = 1.25
        scene.fogColor = Tex.horizon
        scene.fogStartDistance = 34
        scene.fogEndDistance = 120
        scene.fogDensityExponent = 1.3

        let light = SCNLight()
        light.type = .directional
        light.intensity = 1450
        light.color = UIColor(red: 1.0, green: 0.95, blue: 0.86, alpha: 1)
        light.castsShadow = true
        light.shadowMode = .forward
        light.shadowColor = UIColor(white: 0, alpha: 0.5)
        light.shadowMapSize = CGSize(width: 2048, height: 2048)
        light.automaticallyAdjustsShadowProjection = true
        light.maximumShadowDistance = 34
        light.shadowCascadeCount = 1
        light.shadowRadius = 1.5
        light.shadowBias = 2
        sun.light = light
        sun.eulerAngles = SCNVector3(-0.95, 0.5, 0)
        root.addChildNode(sun)

        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 200
        amb.color = UIColor(hex: 0xB8D4F0)
        ambient.light = amb
        root.addChildNode(ambient)

        let shop = SCNLight()
        shop.type = .omni
        shop.intensity = 0
        shop.color = UIColor(hex: 0xFFC27A)
        shop.attenuationStartDistance = 2
        shop.attenuationEndDistance = 7.5
        shop.castsShadow = false
        shopLight.light = shop
        shopLight.position = SCNVector3(0, 2.75, 0.2)
        root.addChildNode(shopLight)

        // Rain
        rainNode.position = SCNVector3(0, 12, 2)
        let rain = Effects.rain()
        rainNode.addParticleSystem(rain)
        rainPS = rain
        let splashNode = SCNNode()
        splashNode.position = SCNVector3(0, -11.9, 2)
        let splash = Effects.splash()
        splashNode.addParticleSystem(splash)
        rainNode.addChildNode(splashNode)
        splashPS = splash

        buildSelection()
        buildHint()
        applyQuality()
    }

    private func applyQuality() {
        let cam = rig.camera
        cam.wantsHDR = true
        cam.wantsExposureAdaptation = false
        cam.exposureOffset = -0.3
        cam.bloomIntensity = highQuality ? 0.45 : 0
        cam.bloomThreshold = 1.0
        cam.bloomBlurRadius = 5
        cam.bloomIterationCount = 1
        cam.screenSpaceAmbientOcclusionIntensity = 0
        cam.saturation = 1.08
        cam.contrast = 0.1
        cam.vignettingIntensity = 0.32
        cam.vignettingPower = 0.6
        sun.light?.shadowSampleCount = highQuality ? 4 : 1
        sun.light?.shadowRadius = highQuality ? 2 : 1
        view?.antialiasingMode = highQuality ? .multisampling4X : .multisampling2X
    }

    /// Compile shaders for everything up front so nothing pops in later.
    func prewarm() {
        guard let v = view else { return }
        var nodes: [SCNNode] = [envRoot, dynRoot]
        for d in Dish.allCases { nodes.append(dishes.node(d)) }
        v.prepare(nodes, completionHandler: nil)
    }

    // MARK: Location

    func load(_ i: Int, sim: Simulation) {
        loc = i
        let info = Catalog.locations[i]
        envRoot.childNodes.forEach { $0.removeFromParentNode() }
        let e = envCache[i] ?? LocationBuilder.build(info)
        envCache[i] = e
        env = e
        envRoot.addChildNode(e.root)

        dynRoot.childNodes.forEach { $0.removeFromParentNode() }
        peopleRoot.childNodes.forEach { $0.removeFromParentNode() }
        fxRoot.childNodes.forEach { $0.removeFromParentNode() }
        carsRoot.childNodes.forEach { $0.removeFromParentNode() }
        giftRoot.childNodes.forEach { $0.removeFromParentNode() }
        gift = nil
        stations = [nil, nil, nil, nil]
        stationKeys = ["", "", "", ""]
        PersonView.purge()
        cashiers = []
        windowNodes = []
        windowsShown = -1
        decorNode = nil
        decorShown = -1
        decorNight = []
        menuKey = ""
        customers = [:]
        courier = nil
        courierPerson = nil
        courierBubble = nil
        courierKey = ""
        flyers = []
        lastNight = -1
        selection.isHidden = true

        // Invisible pick volume for the counter
        let pickMat = SCNMaterial()
        pickMat.colorBufferWriteMask = []
        pickMat.writesToDepthBuffer = false
        let counter = Geo.box(8.2, 1.2, 1.3, pickMat).at(0, 0.6, 1.15)
        counter.name = "counter"
        counter.isHidden = true
        counter.categoryBitMask = SceneRenderer.pickMask
        counter.castsShadow = false
        dynRoot.addChildNode(counter)

        refreshStructure(sim, animated: false)
        makeCars()
        rig.reset()
        rig.snap()
    }

    /// Updates stations, cashiers, decor and the menu board when the player buys something.
    func refreshStructure(_ sim: Simulation, animated: Bool) {
        guard loc >= 0 else { return }
        let info = Catalog.locations[loc]
        let L = sim.s.locations[loc]

        for j in 0..<4 {
            let st = L.stations[j]
            let key = st.level > 0 ? "o\(st.cooks)" : "l"
            guard key != stationKeys[j] else { continue }
            let wasOpen = stationKeys[j].hasPrefix("o")
            stationKeys[j] = key
            stations[j]?.node.removeFromParentNode()
            let d = info.dishes[j]
            var sign: UIImage?
            if st.level == 0 {
                sign = Tex.lockedSign(dish: d, price: Fmt.money(info.stationCosts[j]), icon: icons[d.iconKey])
            }
            let v = StationView(index: j, dish: d, open: st.level > 0, cooks: st.cooks, loc: loc, dishes: dishes, sign: sign)
            dynRoot.addChildNode(v.node)
            stations[j] = v
            if animated {
                if st.level > 0 && !wasOpen {
                    v.node.scale = SCNVector3(0.3, 0.3, 0.3)
                    v.node.runAction(.sequence([.scale(to: 1.12, duration: 0.3), .scale(to: 1, duration: 0.15)]))
                    burst(Effects.dust(), at: SIMD3(Layout.stationX[j], 0.15, Layout.stationZ))
                    burst(Effects.sparkle(), at: SIMD3(Layout.stationX[j], 1.2, Layout.stationZ))
                    burst(Effects.confetti(), at: SIMD3(Layout.stationX[j], 1.0, Layout.stationZ + 0.6))
                } else {
                    for c in v.cooks.suffix(1) {
                        c.root.scale = SCNVector3(0.1, 0.1, 0.1)
                        let pop = SCNAction.scale(to: 1, duration: 0.3)
                        pop.timingMode = .easeOut
                        c.root.runAction(pop)
                        burst(Effects.sparkle(), at: SIMD3(Layout.stationX[j] + c.root.position.x, 1.0, Layout.stationZ + 0.8))
                    }
                }
            }
        }

        if L.windows != windowsShown {
            let old = windowsShown
            windowsShown = L.windows
            windowNodes.forEach { $0.removeFromParentNode() }
            windowNodes = []
            cashiers = []
            for w in 0..<L.windows {
                let holder = SCNNode()
                holder.position = SCNVector3(Layout.windowX[w], 0, 0)
                let cashier = PersonView(role: .cashier(accent: info.theme.accent == 0x1A1A1A ? 0xC9A227 : info.theme.accent), look: w * 11 + loc * 5 + 3)
                cashier.root.position = SCNVector3(0, 0.12, 0.62)
                cashier.root.eulerAngles.y = Float.pi
                holder.addChildNode(cashier.root)
                let screen = M.screen
                let reg = merged([
                    Geo.box(0.42, 0.14, 0.32, M.black, chamfer: 0.02).at(0, 0.07, 0),
                    Geo.box(0.36, 0.04, 0.26, M.steelDark).at(0, 0.16, 0),
                    Geo.box(0.04, 0.2, 0.04, M.black).at(0, 0.24, -0.08),
                    Geo.box(0.3, 0.2, 0.03, screen).at(0, 0.38, -0.08).rot(-0.25, 0, 0),
                ])
                reg.position = SCNVector3(-0.55, 0.81, 1.12)
                reg.eulerAngles.y = 0.25
                holder.addChildNode(reg)
                dynRoot.addChildNode(holder)
                windowNodes.append(holder)
                cashiers.append(cashier)
                if animated && old >= 0 && w >= old {
                    holder.scale = SCNVector3(0.2, 0.2, 0.2)
                    let pop = SCNAction.sequence([.scale(to: 1.1, duration: 0.25), .scale(to: 1, duration: 0.12)])
                    holder.runAction(pop)
                    burst(Effects.sparkle(), at: SIMD3(Layout.windowX[w], 1.4, 1.0))
                }
            }
        }

        if L.decor != decorShown {
            let old = decorShown
            decorShown = L.decor
            decorNode?.removeFromParentNode()
            decorNight = []
            let d = LocationBuilder.decor(level: L.decor, info: info, dishes: dishes, night: &decorNight)
            dynRoot.addChildNode(d)
            decorNode = d
            lastNight = -1
            if animated && old >= 0 && L.decor > old {
                burst(Effects.confetti(), at: SIMD3(0, 2.5, 2.0))
                burst(Effects.sparkle(), at: SIMD3(-3, 1.5, 2.5))
                burst(Effects.sparkle(), at: SIMD3(3, 1.5, 2.5))
            }
        }

        refreshMenu(sim)
    }

    /// Dish icons are rendered after launch: redraw the boards that show them.
    func iconsReady(_ sim: Simulation) {
        for j in 0..<4 where stationKeys[j] == "l" { stationKeys[j] = "" }
        menuKey = ""
        refreshStructure(sim, animated: false)
    }

    func refreshMenu(_ sim: Simulation) {
        guard loc >= 0, let env else { return }
        let info = Catalog.locations[loc]
        let L = sim.s.locations[loc]
        let prices = (0..<4).map { L.stations[$0].level > 0 ? Rules.price(info.dishes[$0], L.stations[$0].level) * sim.s.priceMult : 0 }
        let key = prices.map { Fmt.money($0) }.joined(separator: "|") + "|\(icons.count)"
        guard key != menuKey else { return }
        menuKey = key
        let img = Tex.menuBoard(info.dishes, icons: icons, prices: prices)
        env.menu.diffuse.contents = img
        env.menu.emission.contents = img
    }

    // MARK: Cars

    private func makeCars() {
        cars = []
        let colors: [UInt32] = [0xE53935, 0x1E88E5, 0xFDD835, 0xFAFAFA, 0x263238, 0x43A047, 0xFB8C00, 0x8E24AA]
        for k in 0..<6 {
            let dir: Float = k % 2 == 0 ? 1 : -1
            let z: Float = dir > 0 ? 9.45 : 8.1
            let kind = [0, 1, 2, 0, 0, 2][k]
            let x = -dir * 22 + dir * Float(k / 2) * 15
            let car = CarView(kind: kind, color: kind == 1 ? 0xFFC107 : colors[(k * 3 + loc) % colors.count], dir: dir, z: z, x: x, beam: beamMat)
            carsRoot.addChildNode(car.node)
            cars.append(car)
        }
    }

    private func updateCars(_ dt: Double) {
        for car in cars {
            if car.wait > 0 {
                car.wait -= dt
                continue
            }
            car.x += car.dir * car.speed * Float(dt)
            if abs(car.x) > 24 {
                car.x = -car.dir * 24
                car.wait = Double.random(in: 0.5...5)
                car.speed = Float.random(in: 3.2...5.4)
            }
            car.node.position = SCNVector3(car.x, 0.02, car.z)
        }
    }

    // MARK: Selection & hints

    private func buildSelection() {
        let ring = SCNMaterial()
        ring.lightingModel = .constant
        ring.diffuse.contents = Tex.ringGlow
        ring.multiply.contents = UIColor(hex: 0xFFD54A)
        ring.blendMode = .add
        ring.writesToDepthBuffer = false
        let plane = Geo.floor(1, 1, ring)
        plane.castsShadow = false
        plane.renderingOrder = 30
        selection.addChildNode(plane)
        selection.isHidden = true
        selection.runAction(.repeatForever(.sequence([.fadeOpacity(to: 0.45, duration: 0.55), .fadeOpacity(to: 1, duration: 0.55)])))
    }

    private func buildHint() {
        let arrow = SCNNode()
        arrow.add(
            Geo.cone(0.3, 0, 0.42, highlight, segments: 16).at(0, 0, 0),
            Geo.cylinder(0.11, 0.48, highlight, segments: 12).at(0, 0.45, 0)
        )
        arrow.eulerAngles.x = Float.pi
        arrow.position = SCNVector3(0, 0.25, 0)
        let holder = SCNNode()
        holder.addChildNode(arrow)
        let bob = SCNAction.sequence([.moveBy(x: 0, y: 0.35, z: 0, duration: 0.45), .moveBy(x: 0, y: -0.35, z: 0, duration: 0.45)])
        bob.timingMode = .easeInEaseOut
        holder.runAction(.repeatForever(bob))
        arrow.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 2.4)))
        hint.addChildNode(holder)
        hint.isHidden = true
        hint.enumerateHierarchy { n, _ in n.castsShadow = false }
    }

    func setSelection(_ p: Pick?) {
        guard let p else {
            selection.isHidden = true
            return
        }
        var c = SIMD3<Float>(0, 0.14, 0)
        var size = SIMD2<Float>(2.2, 2.2)
        switch p {
        case .station(let j), .locked(let j):
            c = SIMD3(Layout.stationX[j], 0.14, Layout.stationZ + 0.35)
            size = SIMD2(2.3, 2.3)
        case .counter:
            c = SIMD3(0, 0.1, 1.75)
            size = SIMD2(9.4, 1.5)
        case .courier:
            c = SIMD3(Layout.courierSpot.x, 0.1, Layout.courierSpot.y + 0.4)
            size = SIMD2(2.0, 2.0)
        case .gift:
            selection.isHidden = true
            return
        }
        selection.isHidden = false
        selection.simdPosition = c
        selection.scale = SCNVector3(size.x, 1, size.y)
    }

    func setHint(_ p: SIMD3<Float>?) {
        guard let p else {
            hint.isHidden = true
            return
        }
        hint.isHidden = false
        hint.simdPosition = p
    }

    // MARK: Per-frame update

    func update(_ sim: Simulation, dt: Double) {
        time += dt
        rig.update(dt)
        guard loc >= 0, let env else { return }
        let s = sim.s
        let L = s.locations[loc]
        let info = Catalog.locations[loc]

        // Day, night and weather
        rainLevel += ((sim.raining ? 1 : 0) - rainLevel) * min(1, dt * 0.6)
        let n = Rules.nightFactor(s.dayTime)
        updateSky(dayTime: s.dayTime, night: n)
        if abs(n - lastNight) > 0.004 || lastNight < 0 {
            lastNight = n
            let fn = CGFloat(n)
            for nm in env.night + decorNight {
                nm.material.emission.intensity = nm.day + (nm.night - nm.day) * fn
            }
            for h in env.halos { h.geometry?.firstMaterial?.transparency = fn * 0.85 }
            M.halo.transparency = fn * 0.85
            M.headlight.emission.intensity = 0.3 + 2.4 * fn
            M.taillight.emission.intensity = 0.3 + 1.6 * fn
            beamMat.transparency = fn * 0.5
            env.menu.emission.intensity = 0.15 + 0.8 * fn
        }
        rainPS?.birthRate = rainLevel < 0.03 ? 0 : CGFloat(rainLevel * 1500)
        splashPS?.birthRate = rainLevel < 0.03 ? 0 : CGFloat(rainLevel * 260)
        if let w = env.water {
            waterPhase += Float(dt) * 0.01
            if waterPhase > 1 { waterPhase -= 1 }
            w.normal.contentsTransform = SCNMatrix4Mult(SCNMatrix4MakeScale(24, 10, 1),
                                                        SCNMatrix4MakeTranslation(waterPhase, waterPhase * 0.4, 0))
        }

        // Stations
        for j in 0..<4 {
            guard let v = stations[j] else { continue }
            let st = L.stations[j]
            v.update(st, working: sim.working(loc, j), rate: Rules.rate(info.dishes[j], level: st.level, cooks: st.cooks),
                     time: time, dt: dt)
        }
        // Cashiers
        for (w, c) in cashiers.enumerated() {
            if serveT[w] > 0 {
                serveT[w] = max(0, serveT[w] - dt)
                c.serve(Float(sin((1 - serveT[w] / 0.45) * Double.pi)))
            } else {
                c.animate(moving: false, speed: 1, dt: Float(dt))
            }
        }

        syncCustomers(sim, dt: dt)
        updateCourier(sim, dt: dt)
        updateCars(dt)
        updateFlyers()
        updateGift(dt)
        updateFlicker(env, night: n, dt: dt)
    }

    // MARK: Gift balloon

    var hasGift: Bool { gift != nil }

    /// A balloon with a present drifts over the street; tapping it gives a bonus.
    func spawnGift(at x: Float? = nil, dir: Float? = nil) {
        guard gift == nil, loc >= 0 else { return }
        let colors: [UInt32] = [0xFF5252, 0x7C4DFF, 0x00BFA5, 0xFFB300, 0xFF4081]
        let col = colors.randomElement() ?? 0xFF5252
        let c = MaterialCache.shared
        let ball = Geo.sphere(0.42, c.pbr(col, rough: 0.22), segments: 18)
        ball.scale = SCNVector3(1, 1.15, 1)
        let ribbon = c.pbr(0xFFD54F, rough: 0.4)
        let body = merged([
            ball.at(0, 1.3, 0),
            Geo.cone(0.0, 0.07, 0.1, c.pbr(col, rough: 0.3), segments: 8).at(0, 0.82, 0),
            Geo.cylinder(0.008, 0.62, M.white, segments: 4).at(0, 0.48, 0),
            Geo.box(0.4, 0.32, 0.4, c.pbr(0xE53935, rough: 0.5), chamfer: 0.02).at(0, 0.0, 0),
            Geo.box(0.42, 0.33, 0.08, ribbon).at(0, 0.0, 0),
            Geo.box(0.08, 0.33, 0.42, ribbon).at(0, 0.0, 0),
            Geo.torus(0.06, 0.02, ribbon).at(-0.06, 0.2, 0).rot(0, 0, 0.6),
            Geo.torus(0.06, 0.02, ribbon).at(0.06, 0.2, 0).rot(0, 0, -0.6),
        ])
        let shine = Geo.sphere(0.08, c.flat("giftShine", UIColor(white: 1, alpha: 0.85), alpha: true), segments: 6).at(-0.15, 1.5, -0.32)
        let n = SCNNode()
        n.name = "gift"
        n.addChildNode(body)
        n.addChildNode(shine)
        let pickMat = SCNMaterial()
        pickMat.colorBufferWriteMask = []
        let pick = Geo.sphere(1.0, pickMat, segments: 6).at(0, 0.8, 0)
        pick.isHidden = true
        n.addChildNode(pick)
        n.enumerateHierarchy { node, _ in node.categoryBitMask |= SceneRenderer.pickMask }
        giftDir = dir ?? (Bool.random() ? 1 : -1)
        giftX = x ?? -giftDir * 12
        n.position = SCNVector3(giftX, 4.0, 3.4)
        n.scale = SCNVector3(0.1, 0.1, 0.1)
        n.runAction(.scale(to: 1, duration: 0.4))
        giftRoot.addChildNode(n)
        gift = n
    }

    private func updateGift(_ dt: Double) {
        guard let g = gift else { return }
        giftX += giftDir * Float(dt) * 0.9
        g.position = SCNVector3(giftX, 4.0 + sin(Float(time) * 1.6) * 0.25, 3.4)
        g.eulerAngles.z = sin(Float(time) * 1.1) * 0.12
        if abs(giftX) > 13.5 {
            g.removeFromParentNode()
            gift = nil
        }
    }

    /// Pops the balloon. Returns where it was.
    func collectGift() -> SIMD3<Float>? {
        guard let g = gift else { return nil }
        let p = g.simdPosition
        gift = nil
        burst(Effects.confetti(), at: p + SIMD3(0, 1.2, 0))
        burst(Effects.sparkle(), at: p + SIMD3(0, 0.3, 0))
        burst(Effects.coins(), at: p)
        g.runAction(.sequence([.group([.scale(to: 1.4, duration: 0.12), .fadeOut(duration: 0.12)]), .removeFromParentNode()]))
        return p
    }

    // MARK: Neon flicker

    private func updateFlicker(_ env: EnvBuild, night n: Double, dt: Double) {
        guard n > 0.6, let sign = env.night.first else { return }
        if flicker > 0 {
            flicker -= dt
            let on = Int(flicker * 22) % 3 != 0
            sign.material.emission.intensity = on ? sign.night : sign.day * 0.4
            if flicker <= 0 { sign.material.emission.intensity = sign.day + (sign.night - sign.day) * CGFloat(n) }
        } else {
            flickerCooldown -= dt
            if flickerCooldown <= 0 {
                flickerCooldown = Double.random(in: 9...20)
                flicker = 0.45
            }
        }
    }

    private func updateSky(dayTime t: Double, night n: Double) {
        let key = Int((n * 20).rounded()) * 10 + Int((rainLevel * 4).rounded())
        let fn = Float(n)
        let rain = Float(rainLevel)
        // Sun travels over the day; moonlight at night.
        let dayPos = Float(min(1, max(0, (t - 0.04) / 0.72)))
        let sunYaw = 0.75 - 1.5 * dayPos
        let sunPitch = -(0.55 + 0.5 * sin(dayPos * Float.pi))
        let moonYaw: Float = -0.4, moonPitch: Float = -1.0
        let k = smooth(fn)
        sun.eulerAngles = SCNVector3(sunPitch + (moonPitch - sunPitch) * k, sunYaw + (moonYaw - sunYaw) * k, 0)
        if let light = sun.light {
            let dayI = 1300 * pow(1 - fn, 1.6) * (1 - 0.55 * rain)
            light.intensity = CGFloat(dayI + 260 * fn)
            let warm = max(0, 1 - abs(fn - 0.35) / 0.35) * (1 - rain)
            let r = 1.0, g = 0.95 - 0.25 * Double(warm), b = 0.86 - 0.4 * Double(warm)
            let nightCol = (0.62, 0.72, 1.0)
            let mixK = Double(k)
            light.color = UIColor(red: r + (nightCol.0 - r) * mixK, green: g + (nightCol.1 - g) * mixK,
                                  blue: b + (nightCol.2 - b) * mixK, alpha: 1)
            light.shadowColor = UIColor(white: 0, alpha: CGFloat(0.5 - 0.25 * rain - 0.15 * fn))
        }
        if let amb = ambient.light {
            amb.intensity = CGFloat(200 - 110 * fn + 60 * rain)
            amb.color = fn > 0.5 ? UIColor(hex: 0x6F86C8) : UIColor(hex: 0xB8D4F0)
        }
        shopLight.light?.intensity = CGFloat(60 + 520 * fn + 160 * rain)
        scene.lightingEnvironment.intensity = CGFloat(1.1 - 0.85 * fn) * CGFloat(1 - 0.3 * rain)

        guard key != skyKey else { return }
        skyKey = key
        scene.background.contents = Tex.skyImage(n, rain: rainLevel)
        let c = Tex.skyColors(Double(Int((n * 20).rounded())) / 20, rain: Double(Int((rainLevel * 4).rounded())) / 4)
        scene.fogColor = c.horizon.color
        scene.fogStartDistance = CGFloat(34 - 14 * rain)
        scene.fogEndDistance = CGFloat(120 - 55 * rain)
    }

    private func smooth(_ x: Float) -> Float {
        let t = max(0, min(1, x))
        return t * t * (3 - 2 * t)
    }

    // MARK: Customers

    private func syncCustomers(_ sim: Simulation, dt: Double) {
        frameNo &+= 1
        let f = frameNo
        let rt = sim.runtimes[loc]
        let k = max(0.85, min(1.8, rig.distance / 16))
        let raining = rainLevel > 0.4
        for c in rt.customers {
            let v: CustomerView
            if let existing = customers[c.id] {
                v = existing
            } else {
                v = CustomerView(c, loc: loc)
                peopleRoot.addChildNode(v.person.root)
                customers[c.id] = v
            }
            v.frame = f
            v.update(c, dt: Float(dt), raining: raining, icons: icons, scale: k, time: time)
        }
        if customers.count != rt.customers.count {
            for (id, v) in customers where v.frame != f {
                v.person.root.removeFromParentNode()
                customers.removeValue(forKey: id)
            }
        }
    }

    // MARK: Courier

    private func updateCourier(_ sim: Simulation, dt: Double) {
        guard let d = sim.runtimes[loc].delivery else {
            if let c = courier {
                c.removeFromParentNode()
                courier = nil
                courierPerson = nil
                courierBubble = nil
                courierKey = ""
            }
            return
        }
        if courier == nil {
            let holder = SCNNode()
            holder.name = "courier"
            let scooter = Props.scooter()
            holder.addChildNode(scooter)
            let p = PersonView(role: .courier, look: 7)
            p.root.position = SCNVector3(-0.05, 0.06, 0)
            p.root.eulerAngles.y = -Float.pi / 2
            p.sit(true)
            holder.addChildNode(p.root)
            let pickMat = SCNMaterial()
            pickMat.colorBufferWriteMask = []
            pickMat.writesToDepthBuffer = false
            let pick = Geo.box(1.6, 2.0, 1.2, pickMat).at(0, 1.0, 0)
            pick.castsShadow = false
            pick.isHidden = true
            holder.addChildNode(pick)
            holder.enumerateHierarchy { n, _ in n.categoryBitMask |= SceneRenderer.pickMask }
            peopleRoot.addChildNode(holder)
            courier = holder
            courierPerson = p
        }
        guard let holder = courier else { return }
        holder.position = SCNVector3(d.pos.x, 0.08, d.pos.y)
        let moving = !d.path.isEmpty
        let targetYaw = d.yaw + Float.pi / 2
        holder.eulerAngles.y = moving ? targetYaw : holder.eulerAngles.y + (targetYaw - holder.eulerAngles.y) * Float(min(1, dt * 5))
        holder.childNodes.first?.position.y = moving ? sin(Float(time) * 30) * 0.008 : 0

        if d.phase == 1 {
            let key = d.needs.map { "\($0.0.rawValue)\(d.got[$0.0, default: 0])" }.joined() + "|\(icons.count)"
            if courierBubble == nil {
                let b = SCNNode()
                b.constraints = [SCNBillboardConstraint()]
                b.position = SCNVector3(0, 2.3, 0)
                holder.addChildNode(b)
                courierBubble = b
                b.scale = SCNVector3(0.1, 0.1, 0.1)
                b.runAction(.scale(to: 1, duration: 0.25))
            }
            if key != courierKey, let b = courierBubble {
                courierKey = key
                b.childNodes.forEach { $0.removeFromParentNode() }
                let img = Tex.deliveryBubble(d.needs, got: d.got, icons: icons)
                let m = SCNMaterial()
                m.lightingModel = .constant
                m.diffuse.contents = img
                m.readsFromDepthBuffer = false
                m.writesToDepthBuffer = false
                let h: CGFloat = 0.7
                let plane = Geo.plane(h * img.size.width / img.size.height, h, m)
                plane.renderingOrder = 80
                plane.castsShadow = false
                b.addChildNode(plane)
                // timer bar
                let back = Geo.plane(0.9, 0.08, {
                    let m = SCNMaterial()
                    m.lightingModel = .constant
                    m.diffuse.contents = UIColor(white: 0.1, alpha: 0.7)
                    m.readsFromDepthBuffer = false
                    m.writesToDepthBuffer = false
                    return m
                }())
                back.position = SCNVector3(0, Float(h) / 2 + 0.08, 0)
                back.renderingOrder = 81
                b.addChildNode(back)
                let fm = SCNMaterial()
                fm.lightingModel = .constant
                fm.diffuse.contents = UIColor(hex: 0x66BB6A)
                fm.readsFromDepthBuffer = false
                fm.writesToDepthBuffer = false
                let fill = Geo.plane(0.86, 0.05, fm)
                fill.name = "timer"
                fill.pivot = SCNMatrix4MakeTranslation(-0.43, 0, 0)
                fill.position = SCNVector3(-0.43, Float(h) / 2 + 0.08, 0.001)
                fill.renderingOrder = 82
                b.addChildNode(fill)
            }
            if let fill = courierBubble?.childNode(withName: "timer", recursively: false) {
                let fr = Float(max(0.02, d.timeLeft / d.total))
                fill.scale = SCNVector3(fr, 1, 1)
                fill.geometry?.firstMaterial?.diffuse.contents = UIColor(hex: fr > 0.5 ? 0x66BB6A : (fr > 0.25 ? 0xFFB300 : 0xE53935))
            }
            let k = max(0.85, min(1.6, rig.distance / 15))
            courierBubble?.scale = SCNVector3(k, k, k)
        } else if let b = courierBubble {
            courierBubble = nil
            courierKey = ""
            b.runAction(.sequence([.scale(to: 0.05, duration: 0.15), .removeFromParentNode()]))
        }
    }

    var courierWorld: SIMD3<Float>? {
        guard let c = courier else { return nil }
        return SIMD3(c.position.x, 1.0, c.position.z)
    }

    // MARK: Events

    func handle(_ e: SimEvent, sim: Simulation) {
        switch e {
        case .produced(let l, let j):
            guard l == loc, let v = stations[j] else { return }
            v.pulse()
        case .collected(let l, let j, let w):
            guard l == loc, let v = stations[j] else { return }
            fly(v.dish, from: v.trayWorld, to: SIMD3(Layout.windowX[w], 0.92, 1.3), duration: 0.4, arc: 1.0)
        case .paid(let l, let w, let amount, let vip):
            guard l == loc else { return }
            if w < serveT.count { serveT[w] = 0.45 }
            let p = SIMD3<Float>(Layout.windowX[w], 2.35, 1.9)
            floatText(Fmt.gain(amount), at: p, color: vip ? 0xFFE082 : 0xFFD54A, big: vip)
            if rig.distance < 24 { burst(Effects.coins(), at: SIMD3(p.x, 1.4, 1.6)) }
            if vip { burst(Effects.sparkle(), at: SIMD3(p.x, 1.6, 2.2)) }
        case .deliveryCollected(let l, let j):
            guard l == loc, let v = stations[j], let to = courierWorld else { return }
            fly(v.dish, from: v.trayWorld, to: to, duration: 0.6, arc: 2.2)
        case .deliveryDone(let l, let reward):
            guard l == loc, let p = courierWorld else { return }
            floatText(Fmt.gain(reward), at: p + SIMD3(0, 1.8, 0), color: 0xA5D6A7, big: true)
            burst(Effects.confetti(), at: p + SIMD3(0, 0.5, 0))
            burst(Effects.coins(), at: p + SIMD3(0, 0.8, 0))
        case .deliveryFailed(let l):
            guard l == loc, let p = courierWorld else { return }
            floatText("Отмена", at: p + SIMD3(0, 1.8, 0), color: 0xFF8A80, big: false)
        default:
            break
        }
    }

    /// Feedback when the player taps a station to help the cooks.
    func tapStation(_ j: Int) {
        guard let v = stations[j] else { return }
        v.pulse()
        v.cooks.first?.hop()
        let p = v.applianceWorld
        burst(Effects.puff(), at: p)
        let ps = Effects.sparkle()
        ps.particleSize = 0.1
        ps.birthRate = 160
        burst(ps, at: p)
    }

    func upgradeEffect(_ j: Int, levels: Int) {
        guard let v = stations[j] else { return }
        v.pulse()
        burst(Effects.sparkle(), at: v.applianceWorld)
        ringEffect(at: SIMD3(Layout.stationX[j], 0.15, Layout.stationZ + 0.3), color: 0xFFD54A)
        floatText(levels > 1 ? "+\(levels) ур." : "Ур. +1", at: SIMD3(Layout.stationX[j], 2.4, Layout.stationZ), color: 0x9CE07A, big: false)
    }

    func milestoneEffect(_ j: Int) {
        burst(Effects.confetti(), at: SIMD3(Layout.stationX[j], 1.6, Layout.stationZ + 0.5))
        floatText("СКОРОСТЬ ×2", at: SIMD3(Layout.stationX[j], 2.9, Layout.stationZ), color: 0xFF8A65, big: true)
        rig.shake = 0.5
    }

    func counterEffect() {
        for w in 0..<windowsShown { burst(Effects.sparkle(), at: SIMD3(Layout.windowX[w], 1.6, 1.0)) }
        ringEffect(at: SIMD3(0, 0.15, 1.2), color: 0x80DEEA)
    }

    func celebrate() {
        for x in [Float(-3), 0, 3] { burst(Effects.confetti(), at: SIMD3(x, 2.5, 1.5)) }
        rig.shake = 0.6
    }

    private func ringEffect(at p: SIMD3<Float>, color: UInt32) {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = Tex.ringGlow
        m.multiply.contents = UIColor(hex: color)
        m.blendMode = .add
        m.writesToDepthBuffer = false
        let n = Geo.floor(1, 1, m)
        n.simdPosition = p
        n.castsShadow = false
        n.renderingOrder = 31
        n.scale = SCNVector3(0.5, 0.5, 0.5)
        fxRoot.addChildNode(n)
        let grow = SCNAction.scale(to: 3.2, duration: 0.6)
        grow.timingMode = .easeOut
        n.runAction(.sequence([.group([grow, .fadeOut(duration: 0.6)]), .removeFromParentNode()]))
    }

    private func fly(_ d: Dish, from: SIMD3<Float>, to: SIMD3<Float>, duration: Double, arc: Float) {
        guard flyers.count < 40 else { return }
        let n = dishes.node(d)
        n.castsShadow = false
        n.simdPosition = from
        n.scale = SCNVector3(1.25, 1.25, 1.25)
        fxRoot.addChildNode(n)
        flyers.append(Flyer(node: n, from: from, to: to, start: time, duration: duration, arc: arc))
    }

    private func updateFlyers() {
        guard !flyers.isEmpty else { return }
        var keep: [Flyer] = []
        keep.reserveCapacity(flyers.count)
        for fl in flyers {
            let t = Float((time - fl.start) / fl.duration)
            if t >= 1 {
                fl.node.removeFromParentNode()
                continue
            }
            let e = t * t * (3 - 2 * t)
            var p = fl.from + (fl.to - fl.from) * e
            p.y += fl.arc * 4 * t * (1 - t)
            fl.node.simdPosition = p
            fl.node.eulerAngles.y = t * 6
            let s = 1.25 - 0.45 * max(0, t - 0.7) / 0.3
            fl.node.scale = SCNVector3(s, s, s)
            keep.append(fl)
        }
        flyers = keep
    }

    func burst(_ ps: SCNParticleSystem, at p: SIMD3<Float>) {
        guard fxRoot.childNodes.count < 90 else { return }
        let n = SCNNode()
        n.simdPosition = p
        n.addParticleSystem(ps)
        fxRoot.addChildNode(n)
        n.runAction(.sequence([.wait(duration: 3.0), .removeFromParentNode()]))
    }

    /// Floating number rendered in the 3D scene (always on top, faces the camera).
    func floatText(_ text: String, at p: SIMD3<Float>, color: UInt32 = 0xFFD54A, big: Bool = false) {
        guard fxRoot.childNodes.count < 80 else { return }
        let img = Tex.label(text, color: color)
        let k = CGFloat(max(0.9, rig.distance / 15)) * (big ? 1.45 : 1)
        let h: CGFloat = 0.5 * k
        let plane = SCNPlane(width: h * img.size.width / max(1, img.size.height), height: h)
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = img
        m.readsFromDepthBuffer = false
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        plane.materials = [m]
        let n = SCNNode(geometry: plane)
        n.renderingOrder = 100
        n.castsShadow = false
        let holder = SCNNode()
        holder.simdPosition = p
        holder.constraints = [SCNBillboardConstraint()]
        holder.addChildNode(n)
        fxRoot.addChildNode(holder)
        n.scale = SCNVector3(0.4, 0.4, 0.4)
        let pop = SCNAction.sequence([.scale(to: 1.18, duration: 0.12), .scale(to: 1.0, duration: 0.1)])
        let rise = SCNAction.moveBy(x: 0, y: 1.0 * k, z: 0, duration: 1.3)
        rise.timingMode = .easeOut
        n.runAction(.sequence([pop, .wait(duration: 0.6), .fadeOut(duration: 0.5)]))
        holder.runAction(.sequence([rise, .removeFromParentNode()]))
    }

    // MARK: Picking & camera

    func viewSize() -> CGSize { view?.bounds.size ?? CGSize(width: 390, height: 844) }

    func ground(_ p: CGPoint) -> SIMD3<Float>? {
        rig.ground(p, viewSize: viewSize())
    }

    func pick(_ p: CGPoint) -> Pick? {
        guard let v = view else { return nil }
        let hits = v.hitTest(p, options: [
            SCNHitTestOption.categoryBitMask: SceneRenderer.pickMask,
            SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue,
            SCNHitTestOption.ignoreHiddenNodes: false,
        ])
        var best: Pick?
        for h in hits {
            var n: SCNNode? = h.node
            while let cur = n {
                if let name = cur.name {
                    if name == "courier" { return .courier }
                    if name == "gift" { return .gift }
                    if name.hasPrefix("st:"), let j = Int(name.dropFirst(3)) {
                        if best == nil { best = .station(j) }
                        break
                    }
                    if name.hasPrefix("lock:"), let j = Int(name.dropFirst(5)) {
                        if best == nil { best = .locked(j) }
                        break
                    }
                    if name == "counter" {
                        if best == nil { best = .counter }
                        break
                    }
                }
                n = cur.parent
            }
            if best != nil { break }
        }
        return best
    }

    @discardableResult
    func panCamera(from a: CGPoint, to b: CGPoint) -> SIMD3<Float> {
        guard let g0 = ground(a), let g1 = ground(b) else { return .zero }
        rig.pan(by: g0 - g1)
        return g0 - g1
    }

    func zoomCamera(scale: CGFloat, around p: CGPoint) {
        let g0 = ground(p)
        rig.zoom(scale: Float(scale))
        if let g0, let g1 = ground(p) { rig.pan(by: g0 - g1) }
    }

    func screenPoint(_ p: SIMD3<Float>) -> CGPoint? {
        guard let v = view else { return nil }
        let s = v.projectPoint(SCNVector3(p.x, p.y, p.z))
        guard s.z > 0, s.z < 1 else { return nil }
        return CGPoint(x: CGFloat(s.x), y: CGFloat(s.y))
    }
}
