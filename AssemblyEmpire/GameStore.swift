import SwiftUI
import QuartzCore
import UIKit

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let icon: String
    let tint: Color

    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

enum SheetKind: String, Identifiable {
    case goals, upgrades, menu, help
    var id: String { rawValue }
}

final class GameStore: ObservableObject {
    @Published private(set) var world: World
    @Published var tool: Tool = .inspect
    @Published var rotation: Dir = .right
    @Published var selected: TilePos?
    @Published var money: Double = 0
    @Published var income: Double = 0
    @Published var goalIndex: Int = 0
    @Published var goalProgress: Double = 0
    @Published var toast: Toast?
    @Published var sheet: SheetKind?
    @Published var refresh: Int = 0
    @Published var cameraToken = UUID()

    private var timer: Timer?
    private var last = CACurrentMediaTime()
    private var hudAccum = 0.0
    private var saveAccum = 0.0
    private var stroke: [TilePos] = []
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notify = UINotificationFeedbackGenerator()

    init() {
        if let saved = GameStore.load() {
            world = saved
        } else {
            world = World.newGame()
        }
        refreshHUD()
        if !world.seenTutorial {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.sheet = .help
            }
        }
        start()
    }

    // MARK: Loop

    private func start() {
        last = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.frame()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func frame() {
        let now = CACurrentMediaTime()
        let dt = min(now - last, 0.1)
        last = now
        world.step(dt)

        if !world.events.isEmpty {
            for e in world.events {
                switch e {
                case .goalDone(let g):
                    notify.notificationOccurred(.success)
                    showToast("Цель «\(g.title)» выполнена! \(Fmt.gain(g.reward))", icon: "rosette", tint: Theme.accent)
                }
            }
            world.events.removeAll()
            refreshHUD()
        }

        hudAccum += dt
        if hudAccum >= 0.2 {
            hudAccum = 0
            refreshHUD()
        }
        saveAccum += dt
        if saveAccum >= 10 {
            saveAccum = 0
            save()
        }
    }

    func refreshHUD() {
        money = world.money
        income = world.incomePerMinute
        goalIndex = world.goalIndex
        goalProgress = world.goalProgress()
        refresh &+= 1
    }

    // MARK: Toasts

    func showToast(_ text: String, icon: String = "info.circle.fill", tint: Color = .white) {
        let t = Toast(text: text, icon: icon, tint: tint)
        toast = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            if self?.toast?.id == t.id { self?.toast = nil }
        }
    }

    // MARK: Unlocks

    func isUnlocked(_ type: BuildingType) -> Bool {
        guard let g = type.unlockGoal else { return true }
        return world.goalIndex > g
    }

    func selectTool(_ t: Tool) {
        if case .build(let type) = t, !isUnlocked(type) {
            let goal = Goal.all[type.unlockGoal ?? 0]
            showToast("\(type.title) откроется после цели «\(goal.title)»", icon: "lock.fill", tint: .orange)
            return
        }
        tool = (tool == t && t != .inspect) ? .inspect : t
        if tool != .inspect { selected = nil }
        impact.impactOccurred(intensity: 0.4)
    }

    func rotateTool() {
        rotation = rotation.cw
        impact.impactOccurred(intensity: 0.5)
    }

    // MARK: Interaction

    func tap(_ p: TilePos) {
        guard world.inBounds(p.x, p.y) else {
            selected = nil
            return
        }
        switch tool {
        case .inspect:
            selected = world.building(p.x, p.y) != nil ? p : nil
        case .demolish:
            demolish(p)
        case .build(let type):
            if let b = world.building(p.x, p.y) {
                if b.type == type && type.hasDirection {
                    b.dir = b.dir.cw
                    rotation = b.dir
                    impact.impactOccurred(intensity: 0.5)
                } else {
                    selected = p
                }
            } else {
                place(type, at: p, dir: rotation)
            }
        }
    }

    @discardableResult
    func place(_ type: BuildingType, at p: TilePos, dir: Dir, quiet: Bool = false) -> Bool {
        guard world.inBounds(p.x, p.y), world.building(p.x, p.y) == nil else { return false }
        guard isUnlocked(type) else { return false }
        if type == .miner && world.resource(p.x, p.y).ore == nil {
            if !quiet { showToast("Бур ставится только на залежь руды", icon: "exclamationmark.triangle.fill", tint: .orange) }
            return false
        }
        guard world.money >= type.cost else {
            if !quiet || toast == nil {
                showToast("Не хватает денег: нужно \(Fmt.money(type.cost))", icon: "dollarsign.circle", tint: .red)
            }
            return false
        }
        world.money -= type.cost
        world.set(Building(type: type, x: p.x, y: p.y, dir: dir), at: p)
        selected = nil
        impact.impactOccurred(intensity: type == .belt ? 0.35 : 0.7)
        refreshHUD()
        return true
    }

    func beginStroke(_ p: TilePos) {
        stroke = []
        extendStroke(p)
    }

    func extendStroke(_ p: TilePos) {
        guard world.inBounds(p.x, p.y) else { return }
        guard let lastTile = stroke.last else {
            addStrokeTile(p, dir: rotation)
            return
        }
        if lastTile == p { return }
        var cur = lastTile
        var guardCount = 0
        while cur != p && guardCount < 200 {
            guardCount += 1
            let dx = p.x - cur.x, dy = p.y - cur.y
            let d: Dir = abs(dx) >= abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
            if let b = world.building(cur.x, cur.y), b.type == .belt {
                b.dir = d
            }
            rotation = d
            cur = cur.moved(d)
            addStrokeTile(cur, dir: d)
        }
    }

    func endStroke() {
        stroke = []
    }

    private func addStrokeTile(_ p: TilePos, dir: Dir) {
        stroke.append(p)
        if let b = world.building(p.x, p.y) {
            if b.type == .belt { b.dir = dir }
            return
        }
        place(.belt, at: p, dir: dir, quiet: true)
    }

    func demolish(_ p: TilePos) {
        guard let b = world.building(p.x, p.y) else { return }
        let refund = (b.type.cost * 0.6).rounded()
        world.money += refund
        world.set(nil, at: p)
        if selected == p { selected = nil }
        impact.impactOccurred(intensity: 0.8)
        refreshHUD()
    }

    func rotate(_ p: TilePos) {
        guard let b = world.building(p.x, p.y), b.type.hasDirection else { return }
        b.dir = b.dir.cw
        impact.impactOccurred(intensity: 0.5)
        refresh &+= 1
    }

    func setRecipe(_ id: String, at p: TilePos) {
        guard let b = world.building(p.x, p.y), b.recipeId != id else { return }
        b.recipeId = id
        b.inputs = [:]
        b.progress = 0
        impact.impactOccurred(intensity: 0.5)
        refresh &+= 1
    }

    func buy(_ u: UpgradeType) {
        let lvl = world.level(u)
        guard lvl < u.maxLevel else { return }
        let cost = u.cost(level: lvl)
        guard world.money >= cost else {
            showToast("Не хватает денег", icon: "dollarsign.circle", tint: .red)
            return
        }
        world.money -= cost
        world.upgrades[u] = lvl + 1
        notify.notificationOccurred(.success)
        refreshHUD()
    }

    func finishTutorial() {
        world.seenTutorial = true
        save()
    }

    func newGame() {
        let w = World.newGame()
        w.seenTutorial = true
        world = w
        selected = nil
        tool = .inspect
        stroke = []
        cameraToken = UUID()
        refreshHUD()
        save()
    }

    // MARK: Persistence

    private static var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("assembly_empire_save.json")
    }

    func save() {
        if let data = try? JSONEncoder().encode(world) {
            try? data.write(to: GameStore.saveURL, options: .atomic)
        }
    }

    private static func load() -> World? {
        guard let data = try? Data(contentsOf: saveURL),
              let w = try? JSONDecoder().decode(World.self, from: data),
              w.isValid else { return nil }
        return w
    }
}
