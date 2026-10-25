import SwiftUI
import SceneKit
import UIKit

enum SheetKind: String, Identifiable {
    case goals, upgrades, menu
    var id: String { rawValue }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let icon: String
    let tint: Color

    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

struct OfflineReport: Identifiable, Equatable {
    let id = UUID()
    let amount: Double
    let seconds: Double
}

struct HUDState: Equatable {
    var money: Double = 0
    var income: Double = 0
    var goalIndex = 0
    var goalProgress: Double = 0
    var contract: Contract?
    var boostTime: Double = 0
    var boostCooldown: Double = 0
    var tutorialStep = 0
    var canBuyUpgrade = false
}

private final class LinkProxy: NSObject {
    weak var owner: GameController?
    init(_ o: GameController) { owner = o }
    @objc func tick(_ l: CADisplayLink) { owner?.frame(l) }
}

private enum DragMode {
    case none, camera, belt, demolish
}

final class GameController: ObservableObject {
    @Published private(set) var world: World
    @Published var tool: Tool = .inspect
    @Published var rotation: Dir = .right
    @Published var selected: TilePos?
    @Published var selectedChunk: Int?
    @Published var toast: Toast?
    @Published var sheet: SheetKind?
    @Published var showTitle: Bool
    @Published var offline: OfflineReport?
    @Published var hud = HUDState()
    @Published var icons: [String: UIImage] = [:]
    @Published var tick = 0
    @Published var soundOn: Bool {
        didSet {
            UserDefaults.standard.set(soundOn, forKey: "soundOn")
            Sound.shared.enabled = soundOn
        }
    }
    @Published var musicOn: Bool {
        didSet {
            UserDefaults.standard.set(musicOn, forKey: "musicOn")
            Sound.shared.setMusic(musicOn)
        }
    }
    @Published var hapticsOn: Bool {
        didSet {
            UserDefaults.standard.set(hapticsOn, forKey: "hapticsOn")
            Haptics.enabled = hapticsOn
        }
    }
    @Published var highQuality: Bool {
        didSet {
            UserDefaults.standard.set(highQuality, forKey: "highQuality")
            renderer.highQuality = highQuality
        }
    }

    let renderer = SceneRenderer()
    let scenario: String?
    let hasSave: Bool
    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var hudAccum = 0.0
    private var saveAccum = 0.0
    private var pendingOffline: OfflineReport?
    private var iconQueue: [(String, () -> SCNNode)] = []
    private lazy var iconRenderer = IconRenderer()
    private var stroke: [TilePos] = []
    private var dragMode: DragMode = .none
    private var lastDragPoint: CGPoint = .zero
    private var lastDemolish: TilePos?
    private var lastCoinSound: Double = 0
    private var lastBeltSound: Double = 0
    private weak var view: SCNView?

    // MARK: Init

    init() {
        let d = UserDefaults.standard
        scenario = d.string(forKey: "scenario")
        soundOn = d.object(forKey: "soundOn") as? Bool ?? true
        hapticsOn = d.object(forKey: "hapticsOn") as? Bool ?? true
        musicOn = d.object(forKey: "musicOn") as? Bool ?? true
        highQuality = d.object(forKey: "highQuality") as? Bool ?? (ProcessInfo.processInfo.physicalMemory > 3_500_000_000)

        var w: World
        var report: OfflineReport?
        var saved = false
        if let s = scenario {
            w = (s == "title" || s == "tutorial") ? World.newGame(seed: 77) : World.demo()
        } else if let loaded = GameController.load() {
            w = loaded
            saved = true
            let away = Date().timeIntervalSince1970 - loaded.lastActive
            if away > 120 && loaded.incomeRate > 0.05 {
                let secs = min(away, loaded.offlineHours * 3600)
                let amount = (loaded.incomeRate * secs * 0.5).rounded()
                if amount >= 1 {
                    loaded.money += amount
                    report = OfflineReport(amount: amount, seconds: away)
                }
            }
        } else {
            w = World.newGame()
        }
        world = w
        hasSave = saved
        pendingOffline = report
        showTitle = scenario == nil || scenario == "title"

        Sound.shared.enabled = soundOn
        Haptics.enabled = hapticsOn
        if scenario == nil { Sound.shared.setMusic(musicOn) }
        renderer.highQuality = highQuality
        renderer.setup(w)
        renderer.rig.orbiting = showTitle
        if showTitle {
            renderer.rig.goalDistance = 24
            renderer.rig.distance = 24
        }

        for t in BuildingType.allCases {
            iconQueue.append((t.iconKey, { [unowned self] in self.renderer.lib.building(t) }))
        }
        for i in ItemType.allCases {
            iconQueue.append((i.iconKey, { [unowned self] in self.renderer.lib.item(i) }))
        }

        publishHUD()
        let proxy = LinkProxy(self)
        let l = CADisplayLink(target: proxy, selector: #selector(LinkProxy.tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l

        if let s = scenario { applyScenario(s) }
    }

    func attach(_ v: SCNView) {
        view = v
        v.scene = renderer.scene
        v.pointOfView = renderer.rig.cameraNode
        v.backgroundColor = UIColor(hex: 0x9CC9E8)
        v.antialiasingMode = highQuality ? .multisampling4X : .multisampling2X
        v.preferredFramesPerSecond = 60
        v.rendersContinuously = true
        v.isPlaying = true
        v.overlaySKScene = renderer.overlay
        renderer.view = v
        renderer.prewarm()
    }

    // MARK: Loop

    fileprivate func frame(_ l: CADisplayLink) {
        let now = l.timestamp
        var dt = lastTime == 0 ? 1.0 / 60.0 : now - lastTime
        lastTime = now
        dt = min(max(dt, 0), 0.1)

        world.step(dt)
        handleEvents()
        renderer.update(world, dt: dt)
        if let v = view, renderer.overlay.size != v.bounds.size, v.bounds.width > 0 {
            renderer.overlay.size = v.bounds.size
        }
        processIconQueue()

        hudAccum += dt
        if hudAccum >= 0.2 {
            hudAccum = 0
            publishHUD()
        }
        saveAccum += dt
        if saveAccum >= 15 {
            saveAccum = 0
            save()
        }
    }

    private func processIconQueue() {
        guard !iconQueue.isEmpty else { return }
        let (key, make) = iconQueue.removeFirst()
        let isItem = key.hasPrefix("item.")
        let img = iconRenderer.render(make(), size: isItem ? 120 : 150)
        icons[key] = img
    }

    func publishHUD() {
        updateTutorial()
        var h = HUDState()
        h.money = world.money
        h.income = world.incomePerMinute
        h.goalIndex = world.goalIndex
        h.goalProgress = world.goalProgress()
        h.contract = world.contract
        h.boostTime = world.boostTime.rounded(.up)
        h.boostCooldown = world.boostCooldown.rounded(.up)
        h.tutorialStep = world.tutorialStep
        h.canBuyUpgrade = UpgradeType.allCases.contains { u in
            let l = world.upgradeLevel(u)
            return l < u.maxLevel && world.money >= u.cost(level: l)
        }
        if h != hud { hud = h }
        if selected != nil || sheet != nil || selectedChunk != nil { tick &+= 1 }
    }

    private func handleEvents() {
        guard !world.events.isEmpty else { return }
        let events = world.events
        world.events.removeAll()
        for e in events {
            switch e {
            case .cash(let x, let y, let amount):
                renderer.cashPopup(x: x, y: y, amount: amount, world: world)
                if world.time - lastCoinSound > 0.35 && !showTitle {
                    lastCoinSound = world.time
                    Sound.shared.play(.coin, volume: 0.28)
                }
            case .goalDone(let i):
                let g = Goal.all[i]
                Sound.shared.play(.goal, volume: 0.7)
                Haptics.success()
                let unlocked = BuildingType.allCases.filter { $0.unlockGoal == i }.map { $0.title }
                var text = "Цель «\(g.title)» выполнена! \(Fmt.gain(g.reward))"
                if !unlocked.isEmpty { text += "\nОткрыто: " + unlocked.joined(separator: ", ") }
                showToast(text, icon: "rosette", tint: Color(hex: 0xFFC94A))
            case .contractNew:
                if let c = world.contract {
                    Sound.shared.play(.contract, volume: 0.6)
                    showToast("Новый контракт: \(c.amount) × \(c.item.title.lowercased())", icon: "doc.text.fill", tint: Color(hex: 0x8AB4F8))
                }
            case .contractDone(let c):
                Sound.shared.play(.goal, volume: 0.7)
                Haptics.success()
                showToast("Контракт выполнен! \(Fmt.gain(c.reward))", icon: "checkmark.seal.fill", tint: Color(hex: 0x4ADE80))
            case .contractFailed:
                showToast("Контракт не выполнен вовремя", icon: "clock.badge.xmark", tint: .orange)
            }
        }
        publishHUD()
    }

    // MARK: Toasts

    func showToast(_ text: String, icon: String = "info.circle.fill", tint: Color = .white) {
        let t = Toast(text: text, icon: icon, tint: tint)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            guard let self, self.toast?.id == t.id else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.toast = nil }
        }
    }

    private func fail(_ text: String) {
        Sound.shared.play(.error, volume: 0.5)
        Haptics.error()
        showToast(text, icon: "exclamationmark.triangle.fill", tint: .orange)
    }

    // MARK: Title / offline

    func startPlaying() {
        Sound.shared.play(.tap)
        withAnimation(.easeInOut(duration: 0.4)) { showTitle = false }
        renderer.rig.orbiting = false
        renderer.rig.focus(SIMD3(24.5, 0, 23), distance: 14)
        renderer.rig.goalYaw = (renderer.rig.yaw / (2 * Float.pi)).rounded() * 2 * Float.pi + 0.5
        if let r = pendingOffline {
            pendingOffline = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self?.offline = r }
            }
        }
        publishHUD()
    }

    func collectOffline() {
        Sound.shared.play(.coin)
        Haptics.success()
        withAnimation { offline = nil }
    }

    // MARK: Tools

    func isUnlocked(_ t: BuildingType) -> Bool { world.isUnlocked(t) }

    func selectTool(_ t: Tool) {
        if case .build(let type) = t, !isUnlocked(type) {
            let g = Goal.all[type.unlockGoal ?? 0]
            fail("«\(type.title)» откроется после цели «\(g.title)»")
            return
        }
        tool = (tool == t && t != .inspect) ? .inspect : t
        if tool != .inspect { select(nil) }
        selectedChunk = nil
        Sound.shared.play(.tap, volume: 0.5)
        Haptics.soft(0.4)
        publishHUD()
    }

    func rotateTool() {
        rotation = rotation.cw
        Sound.shared.play(.tap, volume: 0.5)
        Haptics.soft(0.5)
    }

    func select(_ p: TilePos?) {
        selected = p
        renderer.setSelection(p)
    }

    // MARK: Input

    func handleTap(_ p: CGPoint) {
        guard !showTitle else { return }
        guard let t = renderer.pick(p), world.inBounds(t.x, t.y) else {
            select(nil)
            selectedChunk = nil
            return
        }
        if !world.isOwnedTile(t.x, t.y) {
            let c = world.chunkOf(t.x, t.y)
            select(nil)
            if world.canBuyChunk(c) {
                selectedChunk = c
                Sound.shared.play(.tap)
                Haptics.soft()
            } else {
                selectedChunk = nil
                fail("Сначала купите соседний участок")
            }
            return
        }
        selectedChunk = nil
        switch tool {
        case .inspect:
            if world.building(t.x, t.y) != nil {
                select(t)
                Sound.shared.play(.tap, volume: 0.6)
                Haptics.soft(0.4)
            } else {
                select(nil)
            }
        case .demolish:
            demolish(t)
        case .build(let type):
            if let b = world.building(t.x, t.y) {
                if b.type == type && type.hasDirection {
                    rotateBuilding(t)
                    rotation = b.dir
                } else if b.type == .conveyor && type != .conveyor {
                    place(type, at: t)
                } else {
                    select(t)
                }
            } else {
                place(type, at: t)
            }
        }
        publishHUD()
    }

    func dragBegan(start: CGPoint, current: CGPoint) {
        guard !showTitle else { return }
        switch tool {
        case .build(.conveyor):
            dragMode = .belt
            stroke = []
            if let t = renderer.groundTile(start) { extendStroke(t) }
            dragChanged(current)
        case .demolish:
            dragMode = .demolish
            if let t = renderer.groundTile(start) {
                demolish(t)
                lastDemolish = t
            }
            dragChanged(current)
        default:
            dragMode = .camera
            lastDragPoint = start
            dragChanged(current)
        }
    }

    func dragChanged(_ p: CGPoint) {
        switch dragMode {
        case .camera:
            renderer.panCamera(from: lastDragPoint, to: p)
            lastDragPoint = p
        case .belt:
            if let t = renderer.groundTile(p) { extendStroke(t) }
        case .demolish:
            if let t = renderer.groundTile(p), t != lastDemolish {
                demolish(t)
                lastDemolish = t
            }
        case .none:
            break
        }
    }

    func dragEnded() {
        if dragMode == .belt { publishHUD() }
        dragMode = .none
        stroke = []
        lastDemolish = nil
    }

    func cameraPan(from a: CGPoint, to b: CGPoint) {
        guard !showTitle else { return }
        renderer.panCamera(from: a, to: b)
    }

    func cameraZoom(_ scale: CGFloat, around p: CGPoint) {
        guard !showTitle else { return }
        renderer.zoomCamera(scale: scale, around: p)
    }

    func cameraRotate(_ angle: CGFloat) {
        guard !showTitle else { return }
        renderer.rig.rotate(by: Float(angle))
    }

    // MARK: Belt strokes

    private func extendStroke(_ t: TilePos) {
        guard world.inBounds(t.x, t.y) else { return }
        guard let last = stroke.last else {
            addStrokeTile(t, dir: rotation)
            return
        }
        if last == t { return }
        var cur = last
        var guardCount = 0
        while cur != t && guardCount < 100 {
            guardCount += 1
            let dx = t.x - cur.x, dy = t.y - cur.y
            let d: Dir = abs(dx) >= abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
            if let b = world.building(cur.x, cur.y), b.type == .conveyor, b.dir != d {
                b.dir = d
                renderer.refreshBuilding(b, world)
            }
            if rotation != d { rotation = d }
            cur = cur.moved(d)
            addStrokeTile(cur, dir: d)
        }
    }

    private func addStrokeTile(_ p: TilePos, dir: Dir) {
        stroke.append(p)
        if let b = world.building(p.x, p.y) {
            if b.type == .conveyor && b.dir != dir {
                b.dir = dir
                renderer.refreshBuilding(b, world)
            }
            return
        }
        place(.conveyor, at: p, dir: dir, quiet: true)
    }

    // MARK: Actions

    @discardableResult
    func place(_ type: BuildingType, at p: TilePos, dir: Dir? = nil, quiet: Bool = false) -> Bool {
        guard world.isOwnedTile(p.x, p.y), world.isUnlocked(type) else { return false }
        if type == .drill && world.resource(p.x, p.y).ore == nil {
            if !quiet { fail("Бур ставится только на залежь руды") }
            return false
        }
        var refund = 0.0
        if let existing = world.building(p.x, p.y) {
            guard existing.type == .conveyor && type != .conveyor else { return false }
            refund = existing.invested
        }
        guard world.money + refund >= type.cost else {
            if !quiet || toast == nil { fail("Не хватает денег: нужно \(Fmt.money(type.cost))") }
            return false
        }
        if world.building(p.x, p.y) != nil {
            world.set(nil, at: p)
            renderer.removeBuilding(at: p, world, animated: false)
        }
        world.money += refund - type.cost
        let b = world.place(type, p.x, p.y, dir ?? rotation)
        renderer.addBuilding(b, world, animated: true)
        renderer.refreshDeco(at: p, world)
        if type == .conveyor {
            if world.time - lastBeltSound > 0.05 {
                lastBeltSound = world.time
                Sound.shared.play(.belt, volume: 0.45)
            }
            Haptics.soft(0.3)
        } else {
            Sound.shared.play(.place, volume: 0.8)
            Haptics.medium()
        }
        world.checkGoals()
        if !quiet { publishHUD() }
        return true
    }

    func demolish(_ p: TilePos) {
        guard let b = world.building(p.x, p.y) else { return }
        let refund = (b.invested * 0.5).rounded()
        world.money += refund
        world.set(nil, at: p)
        renderer.removeBuilding(at: p, world, animated: true)
        renderer.refreshDeco(at: p, world)
        if selected == p { select(nil) }
        Sound.shared.play(.demolish, volume: 0.7)
        Haptics.medium()
        publishHUD()
    }

    func rotateBuilding(_ p: TilePos) {
        guard let b = world.building(p.x, p.y), b.type.hasDirection else { return }
        b.dir = b.dir.cw
        renderer.refreshBuilding(b, world)
        Sound.shared.play(.tap, volume: 0.6)
        Haptics.soft(0.5)
        tick &+= 1
    }

    func setRecipe(_ id: String, at p: TilePos) {
        guard let b = world.building(p.x, p.y), b.recipeId != id else { return }
        b.recipeId = id
        b.inputs = [:]
        b.progress = 0
        renderer.refreshBuilding(b, world)
        Sound.shared.play(.tap, volume: 0.6)
        Haptics.soft(0.5)
        tick &+= 1
    }

    func upgrade(_ p: TilePos) {
        guard let b = world.building(p.x, p.y), b.type.isUpgradable, b.level < BuildingType.maxLevel else { return }
        let cost = b.type.upgradeCost(level: b.level)
        guard world.money >= cost else {
            fail("Не хватает денег на улучшение")
            return
        }
        world.money -= cost
        b.level += 1
        b.invested += cost
        renderer.upgradeEffect(b, world)
        Sound.shared.play(.upgrade, volume: 0.75)
        Haptics.success()
        world.checkGoals()
        publishHUD()
        tick &+= 1
    }

    func buyChunk(_ c: Int) {
        guard world.canBuyChunk(c) else { return }
        let cost = world.landCost
        guard world.money >= cost else {
            fail("Не хватает денег: нужно \(Fmt.money(cost))")
            return
        }
        world.money -= cost
        world.owned[c] = true
        renderer.chunkPurchased(c, world)
        let cx = c % World.chunks, cy = c / World.chunks
        renderer.rig.focus(SIMD3(Float(cx * 10) + 5, 0, Float(cy * 10) + 5))
        selectedChunk = nil
        Sound.shared.play(.land, volume: 0.8)
        Haptics.success()
        showToast("Новый участок куплен!", icon: "map.fill", tint: Color(hex: 0x4ADE80))
        world.checkGoals()
        publishHUD()
    }

    func buyUpgrade(_ u: UpgradeType) {
        let l = world.upgradeLevel(u)
        guard l < u.maxLevel else { return }
        let cost = u.cost(level: l)
        guard world.money >= cost else {
            fail("Не хватает денег")
            return
        }
        world.money -= cost
        world.upgrades[u] = l + 1
        Sound.shared.play(.upgrade, volume: 0.75)
        Haptics.success()
        publishHUD()
        tick &+= 1
    }

    func activateBoost() {
        guard world.boostTime <= 0 && world.boostCooldown <= 0 else {
            if world.boostTime <= 0 { fail("Ускорение перезаряжается: \(Fmt.duration(world.boostCooldown))") }
            return
        }
        world.boostTime = 60
        world.boostCooldown = 300
        Sound.shared.play(.boost, volume: 0.8)
        Haptics.success()
        showToast("Цены ×2 на 60 секунд!", icon: "bolt.fill", tint: Color(hex: 0xFFC94A))
        publishHUD()
    }

    func focusCamera(on p: TilePos) {
        renderer.rig.focus(SIMD3(Float(p.x) + 0.5, 0, Float(p.y) + 0.5))
    }

    // MARK: Tutorial

    static let tutorialTexts: [String] = [
        "Добро пожаловать в Assembly Empire! Бур добывает железную руду, конвейер везёт её на рынок, а рынок приносит деньги.",
        "Выберите «Бур» на панели внизу.",
        "Нажмите на подсвеченную клетку с рудой. Бур выдаёт руду по белой стрелке прямо на конвейер.",
        "Отлично! Поставьте ещё один бур на клетку ниже.",
        "Выберите «Осмотр» (рука) в начале панели.",
        "Нажмите на любой бур, чтобы открыть его карточку.",
        "Нажмите «Улучшить»: бур будет добывать быстрее.",
        "Руда дешёвая, а пластины дорогие. Выберите «Печь».",
        "Поставьте печь на подсвеченный конвейер. Она заменит его и будет плавить руду.",
        "Готово! Выполняйте цели, открывайте новые здания и покупайте земли. Двигайте карту пальцем, крутите и приближайте двумя.",
    ]

    var tutorialActive: Bool { world.tutorialStep < GameController.tutorialTexts.count }

    var tutorialTool: Tool? {
        switch world.tutorialStep {
        case 1: return .build(.drill)
        case 4: return .inspect
        case 7: return .build(.smelter)
        default: return nil
        }
    }

    private func tutorialTarget(_ s: Int) -> TilePos? {
        switch s {
        case 2: return TilePos(23, 22)
        case 3: return TilePos(23, 23)
        case 5: return TilePos(23, 21)
        case 8: return TilePos(25, 23)
        default: return nil
        }
    }

    private func updateTutorial() {
        var s = world.tutorialStep
        guard s < GameController.tutorialTexts.count else { return }
        var selectedDrill = false
        if let p = selected, world.building(p.x, p.y)?.type == .drill { selectedDrill = true }
        while true {
            let done: Bool
            switch s {
            case 1: done = tool == .build(.drill) || world.count(of: .drill) >= 2
            case 2: done = world.count(of: .drill) >= 2
            case 3: done = world.count(of: .drill) >= 3
            case 4: done = tool == .inspect || world.maxLevel >= 2
            case 5: done = selectedDrill || world.maxLevel >= 2
            case 6: done = world.maxLevel >= 2
            case 7: done = tool == .build(.smelter) || world.count(of: .smelter) >= 1
            case 8: done = world.count(of: .smelter) >= 1
            default: done = false
            }
            if done { s += 1 } else { break }
        }
        if s != world.tutorialStep {
            world.tutorialStep = s
            Sound.shared.play(.contract, volume: 0.35)
        }
        renderer.setHint(showTitle ? nil : tutorialTarget(s))
    }

    func advanceTutorial() {
        world.tutorialStep += 1
        Sound.shared.play(.tap)
        publishHUD()
    }

    func skipTutorial() {
        world.tutorialStep = 100
        renderer.setHint(nil)
        publishHUD()
    }

    // MARK: New game & persistence

    func newGame() {
        let w = World.newGame()
        w.tutorialStep = 100
        world = w
        select(nil)
        selectedChunk = nil
        tool = .inspect
        rotation = .right
        stroke = []
        renderer.setup(w)
        renderer.rig.focus(SIMD3(24.5, 0, 23), distance: 14)
        publishHUD()
        save()
    }

    private static var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("assembly_empire_3d.json")
    }

    func save() {
        guard scenario == nil else { return }
        world.lastActive = Date().timeIntervalSince1970
        guard let data = try? JSONEncoder().encode(world) else { return }
        DispatchQueue.global(qos: .utility).async {
            try? data.write(to: GameController.saveURL, options: .atomic)
        }
    }

    private static func load() -> World? {
        guard let data = try? Data(contentsOf: saveURL),
              let w = try? JSONDecoder().decode(World.self, from: data),
              w.isValid else { return nil }
        return w
    }

    // MARK: QA scenarios (launch argument -scenario <name>)

    private func applyScenario(_ s: String) {
        let rig = renderer.rig
        switch s {
        case "title":
            break
        case "tutorial":
            world.tutorialStep = 2
            tool = .build(.drill)
            rig.focus(SIMD3(24.5, 0, 23), distance: 12)
        case "inspector":
            rig.focus(SIMD3(25, 0, 25.5), distance: 15)
            select(TilePos(24, 25))
        case "build":
            tool = .build(.conveyor)
            rig.focus(SIMD3(25, 0, 25), distance: 16)
        case "upgrades":
            rig.focus(SIMD3(25, 0, 25), distance: 18)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.sheet = .upgrades }
        case "goals":
            rig.focus(SIMD3(25, 0, 25), distance: 18)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.sheet = .goals }
        case "menu":
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.sheet = .menu }
        case "closeup":
            rig.focus(SIMD3(24.8, 0, 24.5), distance: 6.5)
            rig.goalYaw = 0.9
        case "land":
            rig.focus(SIMD3(15, 0, 20), distance: 26)
            selectedChunk = 6
        case "wide":
            rig.focus(SIMD3(25, 0, 25), distance: 40)
        case "icons":
            rig.focus(SIMD3(25, 0, 25), distance: 30)
        default:
            rig.focus(SIMD3(25, 0, 24.5), distance: 16)
        }
        rig.snap()
        publishHUD()
        if s != "title" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self else { return }
                print("[QA] scenario=\(s) money=\(self.world.money) buildings=\(self.world.buildingCount) icons=\(self.icons.count)")
            }
        }
    }
}
