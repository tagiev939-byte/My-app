import Foundation

// MARK: - Random

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Building

final class Building: Codable {
    var type: BuildingType
    var x: Int
    var y: Int
    var dir: Dir
    var recipeId: String?

    var progress: Double = 0
    var inputs: [String: Int] = [:]
    var output: [ItemType] = []

    // Belt / splitter payload
    var item: ItemType?
    var itemProgress: Double = 0
    var itemFrom: Dir = .down
    var splitIndex: Int = 0

    var working: Bool = false
    var pendingCash: Double = 0
    var cashTimer: Double = 0
    var lastSaleTime: Double = -10

    init(type: BuildingType, x: Int, y: Int, dir: Dir) {
        self.type = type
        self.x = x
        self.y = y
        self.dir = dir
        self.recipeId = Recipe.list(for: type).first?.id
    }

    var pos: TilePos { TilePos(x: x, y: y) }
    var recipe: Recipe? { recipeId.flatMap { Recipe.byId($0) } }

    func count(_ item: ItemType) -> Int { inputs[item.rawValue] ?? 0 }
    func add(_ item: ItemType, _ n: Int) { inputs[item.rawValue] = count(item) + n }

    var hasAllInputs: Bool {
        guard let r = recipe else { return false }
        return r.inputs.allSatisfy { count($0.item) >= $0.count }
    }

    static let outputCapacity = 4
}

struct FloatText {
    let x: Int
    let y: Int
    let text: String
    let birth: Double
}

enum WorldEvent {
    case goalDone(Goal)
}

// MARK: - World

final class World: Codable {
    static let width = 40
    static let height = 40
    static let minerTime = 1.6

    var resources: [Resource]
    var buildings: [Building?]
    var money: Double
    var totalEarned: Double = 0
    var produced: [ItemType: Int] = [:]
    var sold: [ItemType: Int] = [:]
    var goalIndex: Int = 0
    var upgrades: [UpgradeType: Int] = [:]
    var time: Double = 0
    var seenTutorial: Bool = false

    // Transient
    var floats: [FloatText] = []
    var events: [WorldEvent] = []
    var buckets: [Double] = Array(repeating: 0, count: 60)
    var bucketIndex = 0
    var bucketClock: Double = 0

    enum CodingKeys: String, CodingKey {
        case resources, buildings, money, totalEarned, produced, sold, goalIndex, upgrades, time, seenTutorial
    }

    init(resources: [Resource], money: Double) {
        self.resources = resources
        self.buildings = Array(repeating: nil, count: World.width * World.height)
        self.money = money
    }

    var isValid: Bool {
        resources.count == World.width * World.height && buildings.count == World.width * World.height
    }

    // MARK: Access

    func inBounds(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < World.width && y < World.height }
    func index(_ x: Int, _ y: Int) -> Int { y * World.width + x }

    func building(_ x: Int, _ y: Int) -> Building? {
        inBounds(x, y) ? buildings[index(x, y)] : nil
    }

    func resource(_ x: Int, _ y: Int) -> Resource {
        inBounds(x, y) ? resources[index(x, y)] : .none
    }

    func set(_ b: Building?, at p: TilePos) {
        guard inBounds(p.x, p.y) else { return }
        buildings[index(p.x, p.y)] = b
    }

    var buildingCount: Int { buildings.reduce(0) { $0 + ($1 == nil ? 0 : 1) } }

    // MARK: Upgrades

    func level(_ u: UpgradeType) -> Int { upgrades[u] ?? 0 }
    var minerMult: Double { 1 + 0.25 * Double(level(.miners)) }
    var beltSpeed: Double { 1.6 * (1 + 0.25 * Double(level(.belts))) }
    var machineMult: Double { 1 + 0.25 * Double(level(.machines)) }
    var priceMult: Double { 1 + 0.15 * Double(level(.prices)) }

    var incomePerMinute: Double { buckets.reduce(0, +) }

    // MARK: Goals

    var currentGoal: Goal? { goalIndex < Goal.all.count ? Goal.all[goalIndex] : nil }

    func goalProgress() -> Double {
        guard let g = currentGoal else { return 1 }
        return min(1, g.current(self) / g.target)
    }

    private func checkGoals() {
        while let g = currentGoal, g.current(self) >= g.target {
            money += g.reward
            goalIndex += 1
            events.append(.goalDone(g))
        }
    }

    // MARK: New game

    static func newGame() -> World {
        let w = World.width, h = World.height
        var rng = SeededRNG(seed: UInt64(Date().timeIntervalSince1970 * 1000))
        var res = [Resource](repeating: .none, count: w * h)

        func blob(_ cx: Int, _ cy: Int, _ r: Double, _ type: Resource) {
            let ri = Int(r) + 1
            for y in max(0, cy - ri)...min(h - 1, cy + ri) {
                for x in max(0, cx - ri)...min(w - 1, cx + ri) {
                    let d = hypot(Double(x - cx), Double(y - cy))
                    let noise = Double.random(in: 0...1, using: &rng)
                    if d < r * (0.7 + 0.45 * noise) {
                        res[y * w + x] = type
                    }
                }
            }
        }

        let c = w / 2
        blob(c - 5, c - 3, 3.0, .iron)
        blob(c + 5, c - 4, 2.7, .copper)
        blob(c - 4, c + 5, 2.5, .stone)
        blob(c + 5, c + 5, 2.4, .coal)

        let kinds: [Resource] = [.iron, .copper, .stone, .coal, .iron, .copper]
        var placed = 0
        var attempts = 0
        while placed < 16 && attempts < 500 {
            attempts += 1
            let x = Int.random(in: 3..<(w - 3), using: &rng)
            let y = Int.random(in: 3..<(h - 3), using: &rng)
            if hypot(Double(x - c), Double(y - c)) < 10 { continue }
            let kind = kinds[Int.random(in: 0..<kinds.count, using: &rng)]
            blob(x, y, Double.random(in: 2.0...3.8, using: &rng), kind)
            placed += 1
        }

        return World(resources: res, money: 250)
    }

    // MARK: Simulation

    func step(_ dt: Double) {
        time += dt

        bucketClock += dt
        while bucketClock >= 1 {
            bucketClock -= 1
            bucketIndex = (bucketIndex + 1) % buckets.count
            buckets[bucketIndex] = 0
        }

        let speed = beltSpeed
        for i in 0..<buildings.count {
            guard let b = buildings[i] else { continue }
            switch b.type {
            case .belt: updateBelt(b, dt, speed)
            case .splitter: updateSplitter(b, dt, speed)
            case .miner: updateMiner(b, dt)
            case .smelter, .assembler: updateMachine(b, dt)
            case .seller: updateSeller(b, dt)
            }
        }

        if !floats.isEmpty {
            floats.removeAll { time - $0.birth > 1.2 }
        }
        checkGoals()
    }

    private func updateBelt(_ b: Building, _ dt: Double, _ speed: Double) {
        guard let item = b.item else { return }
        if b.itemProgress < 1 {
            b.itemProgress = min(1, b.itemProgress + speed * dt)
        }
        if b.itemProgress >= 1, push(item, from: b, dir: b.dir) {
            b.item = nil
            b.itemProgress = 0
        }
    }

    private func updateSplitter(_ b: Building, _ dt: Double, _ speed: Double) {
        guard let item = b.item else { return }
        if b.itemProgress < 1 {
            b.itemProgress = min(1, b.itemProgress + speed * 2 * dt)
            return
        }
        let order = [b.dir.ccw, b.dir, b.dir.cw]
        for k in 0..<3 {
            let i = (b.splitIndex + k) % 3
            if push(item, from: b, dir: order[i]) {
                b.item = nil
                b.itemProgress = 0
                b.splitIndex = (i + 1) % 3
                return
            }
        }
    }

    private func updateMiner(_ b: Building, _ dt: Double) {
        guard let ore = resource(b.x, b.y).ore else {
            b.working = false
            return
        }
        if let out = b.output.first, push(out, from: b, dir: b.dir) {
            b.output.removeFirst()
        }
        if b.output.isEmpty {
            b.working = true
            b.progress += dt * minerMult / World.minerTime
            if b.progress >= 1 {
                b.progress = 0
                b.output.append(ore)
                produced[ore, default: 0] += 1
            }
        } else {
            b.working = false
        }
    }

    private func updateMachine(_ b: Building, _ dt: Double) {
        guard let r = b.recipe else { b.working = false; return }
        if let out = b.output.first, push(out, from: b, dir: b.dir) {
            b.output.removeFirst()
        }
        if b.output.count < Building.outputCapacity && b.hasAllInputs {
            b.working = true
            b.progress += dt * machineMult / r.time
            if b.progress >= 1 {
                b.progress = 0
                for ing in r.inputs { b.add(ing.item, -ing.count) }
                for _ in 0..<r.outputCount { b.output.append(r.output) }
                produced[r.output, default: 0] += r.outputCount
            }
        } else {
            b.working = false
        }
    }

    private func updateSeller(_ b: Building, _ dt: Double) {
        b.cashTimer += dt
        if b.cashTimer >= 0.6 {
            b.cashTimer = 0
            if b.pendingCash > 0 {
                floats.append(FloatText(x: b.x, y: b.y, text: Fmt.gain(b.pendingCash), birth: time))
                b.pendingCash = 0
            }
        }
    }

    // MARK: Item transfer

    private func push(_ item: ItemType, from b: Building, dir: Dir) -> Bool {
        guard let t = building(b.x + dir.dx, b.y + dir.dy) else { return false }
        return accept(item, into: t, side: dir.opposite)
    }

    /// `side` is the side of the target tile through which the item enters.
    private func accept(_ item: ItemType, into t: Building, side: Dir) -> Bool {
        switch t.type {
        case .belt:
            guard t.item == nil, side != t.dir else { return false }
            t.item = item
            t.itemProgress = 0
            t.itemFrom = side
            return true
        case .splitter:
            guard t.item == nil, side == t.dir.opposite else { return false }
            t.item = item
            t.itemProgress = 0
            t.itemFrom = side
            return true
        case .smelter, .assembler:
            guard side != t.dir, let r = t.recipe, let need = r.need(item) else { return false }
            if t.count(item) >= max(need * 2, 3) { return false }
            t.add(item, 1)
            return true
        case .seller:
            let v = item.value * priceMult
            money += v
            totalEarned += v
            sold[item, default: 0] += 1
            buckets[bucketIndex] += v
            t.pendingCash += v
            t.lastSaleTime = time
            return true
        case .miner:
            return false
        }
    }

    // MARK: Status

    func status(of b: Building) -> (text: String, ok: Bool) {
        switch b.type {
        case .miner:
            if resource(b.x, b.y).ore == nil { return ("Нет руды под буром", false) }
            return b.working ? ("Добывает", true) : ("Выход заблокирован", false)
        case .smelter, .assembler:
            if b.output.count >= Building.outputCapacity { return ("Выход заблокирован", false) }
            if !b.hasAllInputs { return ("Ждёт ресурсы", false) }
            return ("Работает", true)
        case .belt, .splitter:
            if let i = b.item { return ("Везёт: \(i.title.lowercased())", true) }
            return ("Пусто", true)
        case .seller:
            return time - b.lastSaleTime < 2 ? ("Торгует", true) : ("Ждёт товар", true)
        }
    }
}
