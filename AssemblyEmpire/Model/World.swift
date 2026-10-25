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

/// Deterministic 0..1 hash for decorations.
func tileHash(_ x: Int, _ y: Int, _ k: Int, _ seed: UInt64 = 0) -> Double {
    var h = UInt64(bitPattern: Int64(x &* 73856093 ^ y &* 19349663 ^ k &* 83492791)) ^ seed
    h ^= h >> 33
    h = h &* 0xff51afd7ed558ccd
    h ^= h >> 33
    h = h &* 0xc4ceb9fe1a85ec53
    h ^= h >> 33
    return Double(h % 100_000) / 100_000
}

// MARK: - Cargo & buildings

struct Cargo: Codable {
    var id: Int
    var type: ItemType
    var p: Double
    var from: Dir
    var to: Dir?
}

final class Building: Codable {
    let type: BuildingType
    let x: Int
    let y: Int
    var dir: Dir
    var level: Int = 1
    var recipeId: String?
    var progress: Double = 0
    var inputs: [ItemType: Int] = [:]
    var output: [ItemType] = []
    var lane: [Cargo] = []
    var cross: [Cargo] = []
    var splitIndex: Int = 0
    var invested: Double = 0

    // Transient state
    var working = false
    var pendingCash: Double = 0
    var cashTimer: Double = 0
    var lastSale: Double = -100

    enum CodingKeys: String, CodingKey {
        case type, x, y, dir, level, recipeId, progress, inputs, output, lane, cross, splitIndex, invested
    }

    init(type: BuildingType, x: Int, y: Int, dir: Dir) {
        self.type = type
        self.x = x
        self.y = y
        self.dir = dir
        self.recipeId = Recipe.list(for: type).first?.id
        self.invested = type.cost
    }

    var pos: TilePos { TilePos(x, y) }
    var recipe: Recipe? { recipeId.flatMap { Recipe.byId($0) } }

    func count(_ item: ItemType) -> Int { inputs[item] ?? 0 }

    func hasAllInputs(_ r: Recipe) -> Bool {
        r.inputs.allSatisfy { count($0.item) >= $0.count }
    }
}

enum WorldEvent {
    case cash(x: Int, y: Int, amount: Double)
    case goalDone(Int)
    case contractNew
    case contractDone(Contract)
    case contractFailed(Contract)
}

// MARK: - World

final class World: Codable {
    static let size = 50
    static let chunk = 10
    static let chunks = 5
    static let spacing = 0.5
    static let drillTime = 1.5
    static let startChunk = 12

    var seed: UInt64
    var resources: [Resource]
    var owned: [Bool]
    var buildings: [Building?]
    var money: Double
    var totalEarned: Double = 0
    var produced: [ItemType: Int] = [:]
    var sold: [ItemType: Int] = [:]
    var goalIndex = 0
    var upgrades: [UpgradeType: Int] = [:]
    var time: Double = 0
    var tutorialStep = 0
    var nextId = 1
    var contract: Contract?
    var contractCooldown: Double = 75
    var boostTime: Double = 0
    var boostCooldown: Double = 0
    var incomeRate: Double = 0
    var history: [Double] = []
    var lastActive: Double = Date().timeIntervalSince1970
    var version = 3

    // Transient
    var events: [WorldEvent] = []
    var buckets = [Double](repeating: 0, count: 30)
    var bucketIndex = 0
    private var secondAccum = 0.0
    private var secondIncome = 0.0
    private var historyAccum = 0.0
    private var goalAccum = 0.0

    enum CodingKeys: String, CodingKey {
        case seed, resources, owned, buildings, money, totalEarned, produced, sold, goalIndex, upgrades, time
        case tutorialStep, nextId, contract, contractCooldown, boostTime, boostCooldown, incomeRate, history
        case lastActive, version
    }

    init(seed: UInt64, resources: [Resource], money: Double) {
        self.seed = seed
        self.resources = resources
        self.owned = Array(repeating: false, count: World.chunks * World.chunks)
        self.buildings = Array(repeating: nil, count: World.size * World.size)
        self.money = money
        self.owned[World.startChunk] = true
    }

    var isValid: Bool {
        resources.count == World.size * World.size &&
        buildings.count == World.size * World.size &&
        owned.count == World.chunks * World.chunks && version == 3
    }

    // MARK: Access

    func inBounds(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < World.size && y < World.size }
    func index(_ x: Int, _ y: Int) -> Int { y * World.size + x }

    func building(_ x: Int, _ y: Int) -> Building? {
        inBounds(x, y) ? buildings[index(x, y)] : nil
    }

    func resource(_ x: Int, _ y: Int) -> Resource {
        inBounds(x, y) ? resources[index(x, y)] : .none
    }

    func chunkOf(_ x: Int, _ y: Int) -> Int { (y / World.chunk) * World.chunks + (x / World.chunk) }

    func isOwnedTile(_ x: Int, _ y: Int) -> Bool {
        inBounds(x, y) && owned[chunkOf(x, y)]
    }

    func chunkNeighbors(_ c: Int) -> [Int] {
        let cx = c % World.chunks, cy = c / World.chunks
        var r: [Int] = []
        if cx > 0 { r.append(c - 1) }
        if cx < World.chunks - 1 { r.append(c + 1) }
        if cy > 0 { r.append(c - World.chunks) }
        if cy < World.chunks - 1 { r.append(c + World.chunks) }
        return r
    }

    func canBuyChunk(_ c: Int) -> Bool {
        !owned[c] && chunkNeighbors(c).contains { owned[$0] }
    }

    var ownedCount: Int { owned.filter { $0 }.count }
    var landCost: Double { (600 * pow(2.0, Double(ownedCount - 1))).rounded() }

    func chunkResources(_ c: Int) -> [Resource: Int] {
        let cx = c % World.chunks, cy = c / World.chunks
        var r: [Resource: Int] = [:]
        for y in (cy * World.chunk)..<((cy + 1) * World.chunk) {
            for x in (cx * World.chunk)..<((cx + 1) * World.chunk) {
                let res = resources[index(x, y)]
                if res != .none { r[res, default: 0] += 1 }
            }
        }
        return r
    }

    func set(_ b: Building?, at p: TilePos) {
        guard inBounds(p.x, p.y) else { return }
        buildings[index(p.x, p.y)] = b
    }

    func count(of type: BuildingType) -> Int {
        buildings.reduce(0) { $0 + ($1?.type == type ? 1 : 0) }
    }

    var buildingCount: Int { buildings.reduce(0) { $0 + ($1 == nil ? 0 : 1) } }
    var maxLevel: Int { buildings.reduce(1) { max($0, $1?.level ?? 1) } }

    // MARK: Multipliers

    func upgradeLevel(_ u: UpgradeType) -> Int { upgrades[u] ?? 0 }
    var beltSpeed: Double { 1.25 * (1 + 0.2 * Double(upgradeLevel(.belts))) }
    var automationMult: Double { 1 + 0.15 * Double(upgradeLevel(.automation)) }
    var priceMult: Double { (1 + 0.1 * Double(upgradeLevel(.prices))) * (boostTime > 0 ? 2 : 1) }
    var offlineHours: Double { 2 + Double(upgradeLevel(.offline)) }

    var incomePerMinute: Double { buckets.reduce(0, +) * 2 }

    func drillRate(_ b: Building) -> Double {
        levelMultiplier(b.level) * automationMult / World.drillTime
    }

    func machineRate(_ b: Building, _ r: Recipe) -> Double {
        levelMultiplier(b.level) * automationMult / r.time
    }

    // MARK: Goals

    var currentGoal: Goal? { goalIndex < Goal.all.count ? Goal.all[goalIndex] : nil }

    func goalValue(_ g: Goal) -> Double {
        switch g.kind {
        case .build(let t): return Double(count(of: t))
        case .produce(let i): return Double(produced[i] ?? 0)
        case .earn: return totalEarned
        case .level: return Double(maxLevel)
        case .land: return Double(ownedCount)
        }
    }

    func goalProgress() -> Double {
        guard let g = currentGoal else { return 1 }
        return min(1, goalValue(g) / g.target)
    }

    func checkGoals() {
        while let g = currentGoal, goalValue(g) >= g.target {
            money += g.reward
            events.append(.goalDone(goalIndex))
            goalIndex += 1
        }
    }

    func isUnlocked(_ t: BuildingType) -> Bool {
        guard let g = t.unlockGoal else { return true }
        return goalIndex > g
    }

    // MARK: Simulation

    func step(_ dt: Double) {
        time += dt
        if boostTime > 0 { boostTime = max(0, boostTime - dt) }
        if boostCooldown > 0 { boostCooldown = max(0, boostCooldown - dt) }

        secondAccum += dt
        while secondAccum >= 1 {
            secondAccum -= 1
            incomeRate = incomeRate * 0.95 + secondIncome * 0.05
            secondIncome = 0
            bucketIndex = (bucketIndex + 1) % buckets.count
            buckets[bucketIndex] = 0
            historyAccum += 1
            if historyAccum >= 30 {
                historyAccum = 0
                history.append(incomePerMinute)
                if history.count > 40 { history.removeFirst(history.count - 40) }
            }
        }

        let beltStep = beltSpeed * dt
        for i in 0..<buildings.count {
            guard let b = buildings[i] else { continue }
            switch b.type {
            case .conveyor: updateConveyor(b, beltStep)
            case .splitter: updateSplitter(b, beltStep)
            case .junction: updateJunction(b, beltStep)
            case .drill: updateDrill(b, dt)
            case .smelter, .assembler: updateMachine(b, dt)
            case .market: updateMarket(b, dt)
            }
        }

        updateContract(dt)

        goalAccum += dt
        if goalAccum >= 0.25 {
            goalAccum = 0
            checkGoals()
        }
    }

    private func advance(_ lane: inout [Cargo], _ step: Double) {
        for i in 0..<lane.count {
            let limit = i == 0 ? 1.0 : lane[i - 1].p - World.spacing
            if lane[i].p < limit { lane[i].p = min(limit, lane[i].p + step) }
        }
    }

    private func updateConveyor(_ b: Building, _ step: Double) {
        guard !b.lane.isEmpty else { return }
        advance(&b.lane, step)
        let c = b.lane[0]
        if c.p >= 1, push(c.type, id: c.id, from: b, dir: b.dir) {
            b.lane.removeFirst()
        }
    }

    private func updateJunction(_ b: Building, _ step: Double) {
        if !b.lane.isEmpty {
            advance(&b.lane, step)
            let c = b.lane[0]
            if c.p >= 1, push(c.type, id: c.id, from: b, dir: c.from.opposite) { b.lane.removeFirst() }
        }
        if !b.cross.isEmpty {
            advance(&b.cross, step)
            let c = b.cross[0]
            if c.p >= 1, push(c.type, id: c.id, from: b, dir: c.from.opposite) { b.cross.removeFirst() }
        }
    }

    private func updateSplitter(_ b: Building, _ step: Double) {
        guard !b.lane.isEmpty else { return }
        var c = b.lane[0]
        let order = [b.dir.ccw, b.dir, b.dir.cw]
        if c.p < 0.5 {
            c.p = min(0.5, c.p + step * 1.4)
        } else if c.to == nil {
            for k in 0..<3 {
                let i = (b.splitIndex + k) % 3
                if let t = building(b.x + order[i].dx, b.y + order[i].dy),
                   canAccept(c.type, into: t, side: order[i].opposite) {
                    c.to = order[i]
                    b.splitIndex = (i + 1) % 3
                    break
                }
            }
        } else if c.p < 1 {
            c.p = min(1, c.p + step * 1.4)
        } else if let to = c.to {
            if push(c.type, id: c.id, from: b, dir: to) {
                b.lane.removeAll()
                return
            }
            for d in order where d != to {
                if push(c.type, id: c.id, from: b, dir: d) {
                    b.lane.removeAll()
                    return
                }
            }
        }
        b.lane[0] = c
    }

    private func updateDrill(_ b: Building, _ dt: Double) {
        guard let ore = resource(b.x, b.y).ore else {
            b.working = false
            return
        }
        if let out = b.output.first, pushNew(out, from: b, dir: b.dir) {
            b.output.removeFirst()
        }
        if b.output.count < 2 {
            b.working = true
            b.progress += dt * drillRate(b)
            if b.progress >= 1 {
                b.progress -= 1
                b.output.append(ore)
                produced[ore, default: 0] += 1
            }
        } else {
            b.working = false
        }
    }

    private func updateMachine(_ b: Building, _ dt: Double) {
        guard let r = b.recipe else {
            b.working = false
            return
        }
        if let out = b.output.first, pushNew(out, from: b, dir: b.dir) {
            b.output.removeFirst()
        }
        if b.output.count < 4 && b.hasAllInputs(r) {
            b.working = true
            b.progress += dt * machineRate(b, r)
            if b.progress >= 1 {
                b.progress = 0
                for ing in r.inputs { b.inputs[ing.item, default: 0] -= ing.count }
                for _ in 0..<r.outputCount { b.output.append(r.output) }
                produced[r.output, default: 0] += r.outputCount
            }
        } else {
            b.working = false
        }
    }

    private func updateMarket(_ b: Building, _ dt: Double) {
        b.cashTimer += dt
        if b.cashTimer >= 0.7 {
            b.cashTimer = 0
            if b.pendingCash > 0 {
                events.append(.cash(x: b.x, y: b.y, amount: b.pendingCash))
                b.pendingCash = 0
            }
        }
        b.working = time - b.lastSale < 1.5
    }

    // MARK: Transfer

    func canAccept(_ item: ItemType, into t: Building, side: Dir) -> Bool {
        switch t.type {
        case .conveyor:
            guard side != t.dir else { return false }
            if let last = t.lane.last { return last.p >= World.spacing }
            return true
        case .splitter:
            return side == t.dir.opposite && t.lane.isEmpty
        case .junction:
            let lane = (side == .up || side == .down) ? t.lane : t.cross
            if let last = lane.last { return last.from == side && last.p >= World.spacing }
            return true
        case .smelter, .assembler:
            guard side != t.dir, let r = t.recipe, let need = r.need(item) else { return false }
            return t.count(item) < max(need * 2, 2)
        case .market:
            return true
        case .drill:
            return false
        }
    }

    private func pushNew(_ item: ItemType, from b: Building, dir: Dir) -> Bool {
        if push(item, id: nextId, from: b, dir: dir) {
            nextId += 1
            return true
        }
        return false
    }

    private func push(_ item: ItemType, id: Int, from b: Building, dir: Dir) -> Bool {
        guard let t = building(b.x + dir.dx, b.y + dir.dy) else { return false }
        let side = dir.opposite
        guard canAccept(item, into: t, side: side) else { return false }
        switch t.type {
        case .conveyor, .splitter:
            t.lane.append(Cargo(id: id, type: item, p: 0, from: side, to: nil))
        case .junction:
            if side == .up || side == .down {
                t.lane.append(Cargo(id: id, type: item, p: 0, from: side, to: nil))
            } else {
                t.cross.append(Cargo(id: id, type: item, p: 0, from: side, to: nil))
            }
        case .smelter, .assembler:
            t.inputs[item, default: 0] += 1
        case .market:
            sell(item, at: t)
        case .drill:
            return false
        }
        return true
    }

    private func sell(_ item: ItemType, at m: Building) {
        let v = item.value * priceMult * marketMultiplier(m.level)
        money += v
        totalEarned += v
        secondIncome += v
        buckets[bucketIndex] += v
        sold[item, default: 0] += 1
        m.pendingCash += v
        m.lastSale = time

        if var c = contract, c.item == item, c.delivered < c.amount {
            c.delivered += 1
            if c.delivered >= c.amount {
                money += c.reward
                contract = nil
                contractCooldown = 60
                events.append(.contractDone(c))
            } else {
                contract = c
            }
        }
    }

    // MARK: Contracts

    private func updateContract(_ dt: Double) {
        if var c = contract {
            c.timeLeft -= dt
            if c.timeLeft <= 0 {
                contract = nil
                contractCooldown = 45
                events.append(.contractFailed(c))
            } else {
                contract = c
            }
            return
        }
        contractCooldown -= dt
        if contractCooldown <= 0 {
            if let c = makeContract() {
                contract = c
                events.append(.contractNew)
            } else {
                contractCooldown = 20
            }
        }
    }

    private func makeContract() -> Contract? {
        let candidates = ItemType.allCases
            .filter { (produced[$0] ?? 0) >= 5 }
            .sorted { $0.value > $1.value }
        guard !candidates.isEmpty else { return nil }
        var rng = SeededRNG(seed: seed &+ UInt64(time * 1000))
        let pool = Array(candidates.prefix(4))
        let item = pool[Int.random(in: 0..<pool.count, using: &rng)]
        let amount = max(4, Int(90 / pow(item.value, 0.42)))
        let reward = (item.value * Double(amount) * 1.6 * (1 + 0.1 * Double(upgradeLevel(.prices))) + 50).rounded()
        let duration = 300.0
        return Contract(item: item, amount: amount, delivered: 0, reward: reward, timeLeft: duration, total: duration)
    }

    // MARK: Status

    func status(of b: Building) -> (text: String, ok: Bool) {
        switch b.type {
        case .drill:
            if resource(b.x, b.y).ore == nil { return ("Нет руды под буром", false) }
            return b.working ? ("Добывает", true) : ("Выход заблокирован", false)
        case .smelter, .assembler:
            guard let r = b.recipe else { return ("Нет рецепта", false) }
            if b.output.count >= 4 { return ("Выход заблокирован", false) }
            if !b.hasAllInputs(r) {
                let missing = r.inputs.filter { b.count($0.item) < $0.count }.map { $0.item.title.lowercased() }
                return ("Ждёт: " + missing.joined(separator: ", "), false)
            }
            return ("Работает", true)
        case .conveyor, .splitter, .junction:
            let n = b.lane.count + b.cross.count
            return n > 0 ? ("Везёт предметов: \(n)", true) : ("Пусто", true)
        case .market:
            return b.working ? ("Торгует", true) : ("Ждёт товар", true)
        }
    }

    /// Items per minute this building produces at full speed.
    func ratePerMinute(_ b: Building) -> Double {
        switch b.type {
        case .drill: return drillRate(b) * 60
        case .smelter, .assembler:
            guard let r = b.recipe else { return 0 }
            return machineRate(b, r) * 60 * Double(r.outputCount)
        default: return 0
        }
    }
}

// MARK: - World generation

extension World {
    static let centerDeposits: [(Resource, [(Int, Int)])] = [
        (.iron, [(1, 1), (2, 1), (3, 1), (1, 2), (2, 2), (3, 2), (1, 3), (2, 3), (3, 3)]),
        (.copper, [(7, 1), (8, 1), (7, 2), (8, 2), (7, 3), (8, 3)]),
        (.stone, [(1, 7), (2, 7), (1, 8), (2, 8)]),
        (.coal, [(7, 7), (8, 7), (7, 8), (8, 8)]),
    ]

    static func newGame(seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000) & 0xFFFFFFFF) -> World {
        let n = World.size
        var res = [Resource](repeating: .none, count: n * n)
        var rng = SeededRNG(seed: seed)

        // Starting chunk: fixed layout
        let ox = 20, oy = 20
        for (r, tiles) in centerDeposits {
            for (x, y) in tiles { res[(oy + y) * n + ox + x] = r }
        }

        func blob(_ c: Int, _ type: Resource, _ size: Int) {
            let cx = c % chunks, cy = c / chunks
            let x0 = cx * chunk, y0 = cy * chunk
            var tiles: [(Int, Int)] = []
            for _ in 0..<20 {
                let sx = x0 + Int.random(in: 2...7, using: &rng)
                let sy = y0 + Int.random(in: 2...7, using: &rng)
                if res[sy * n + sx] == .none {
                    tiles.append((sx, sy))
                    break
                }
            }
            guard !tiles.isEmpty else { return }
            res[tiles[0].1 * n + tiles[0].0] = type
            var attempts = 0
            while tiles.count < size && attempts < 200 {
                attempts += 1
                let base = tiles[Int.random(in: 0..<tiles.count, using: &rng)]
                let d = Dir.allCases[Int.random(in: 0..<4, using: &rng)]
                let nx = base.0 + d.dx, ny = base.1 + d.dy
                guard nx > x0, ny > y0, nx < x0 + chunk - 1, ny < y0 + chunk - 1 else { continue }
                guard res[ny * n + nx] == .none else { continue }
                res[ny * n + nx] = type
                tiles.append((nx, ny))
            }
        }

        var ring1: [Int] = []
        var ring2: [Int] = []
        for c in 0..<(chunks * chunks) where c != startChunk {
            let cx = c % chunks, cy = c / chunks
            let ring = max(abs(cx - 2), abs(cy - 2))
            if ring == 1 { ring1.append(c) } else { ring2.append(c) }
        }

        var primaries: [Resource] = [.iron, .copper, .stone, .coal, .gold, .quartz, .iron, .copper]
        primaries.shuffle(using: &rng)
        for (i, c) in ring1.enumerated() {
            blob(c, primaries[i], Int.random(in: 6...9, using: &rng))
            if Int.random(in: 0..<2, using: &rng) == 0 {
                let second: [Resource] = [.coal, .stone, .iron, .copper]
                blob(c, second[Int.random(in: 0..<second.count, using: &rng)], Int.random(in: 4...6, using: &rng))
            }
        }

        let weighted: [Resource] = [.iron, .iron, .iron, .copper, .copper, .copper, .stone, .stone,
                                    .coal, .coal, .gold, .gold, .quartz, .quartz]
        for c in ring2 {
            let count = Int.random(in: 2...3, using: &rng)
            for _ in 0..<count {
                blob(c, weighted[Int.random(in: 0..<weighted.count, using: &rng)], Int.random(in: 6...11, using: &rng))
            }
        }

        let w = World(seed: seed, resources: res, money: 200)

        // Starter production line: drill -> belts -> market
        w.place(.drill, 23, 21, .right)
        w.place(.conveyor, 24, 21, .down)
        w.place(.conveyor, 24, 22, .down)
        w.place(.conveyor, 24, 23, .right)
        w.place(.conveyor, 25, 23, .right)
        w.place(.market, 26, 23, .up)
        return w
    }

    @discardableResult
    func place(_ type: BuildingType, _ x: Int, _ y: Int, _ dir: Dir, level: Int = 1, recipe: String? = nil) -> Building {
        let b = Building(type: type, x: x, y: y, dir: dir)
        b.level = level
        if let recipe { b.recipeId = recipe }
        set(b, at: TilePos(x, y))
        return b
    }

    func line(_ x: Int, _ y: Int, _ dir: Dir, _ count: Int) {
        var p = TilePos(x, y)
        for _ in 0..<count {
            place(.conveyor, p.x, p.y, dir)
            p = p.moved(dir)
        }
    }

    /// A developed factory used for screenshots and QA.
    static func demo() -> World {
        let w = newGame(seed: 424242)
        for c in [7, 11, 13, 17] { w.owned[c] = true }
        w.buildings = Array(repeating: nil, count: size * size)

        // Iron: three drills -> smelter -> gear assembler -> market
        w.place(.drill, 23, 21, .right, level: 4)
        w.place(.drill, 23, 22, .right, level: 3)
        w.place(.drill, 23, 23, .right, level: 3)
        w.line(24, 21, .down, 4)
        w.place(.smelter, 24, 25, .down, level: 3)
        w.place(.conveyor, 24, 26, .down)
        w.place(.assembler, 24, 27, .down, level: 2, recipe: "gear")
        w.place(.conveyor, 24, 28, .right)
        w.place(.conveyor, 25, 28, .right)
        w.place(.market, 26, 28, .up, level: 3)

        // Copper: drills -> smelter -> market
        w.place(.drill, 28, 21, .left, level: 3)
        w.place(.drill, 28, 22, .left, level: 2)
        w.place(.drill, 28, 23, .left, level: 2)
        w.line(27, 21, .down, 4)
        w.place(.smelter, 27, 25, .down, level: 2, recipe: "copperPlate")
        w.place(.conveyor, 27, 26, .left)
        w.place(.conveyor, 26, 26, .down)
        w.place(.conveyor, 26, 27, .down)

        // Coal & stone straight to the market
        w.place(.drill, 27, 27, .left, level: 2)
        w.place(.drill, 22, 28, .right, level: 1)
        w.place(.conveyor, 23, 28, .right)

        // Second market with a splitter
        w.place(.drill, 21, 21, .up, level: 2)
        w.place(.conveyor, 21, 20, .right)
        w.place(.splitter, 22, 20, .right)
        w.place(.conveyor, 23, 20, .right)
        w.place(.market, 24, 20, .up, level: 1)

        w.money = 48_500
        w.totalEarned = 61_200
        w.goalIndex = 7
        w.tutorialStep = 100
        w.produced = [.ironOre: 900, .ironPlate: 500, .gear: 120, .copperPlate: 300, .copperOre: 400, .coal: 80]
        w.upgrades = [.belts: 1, .prices: 2]
        w.contract = Contract(item: .copperPlate, amount: 400, delivered: 180, reward: 4_600, timeLeft: 260, total: 300)
        w.history = [400, 620, 800, 950, 1200, 1500, 1700, 2100, 2400, 2600, 2900, 3300]
        for _ in 0..<1200 { w.step(1.0 / 30.0) }
        w.events.removeAll()
        return w
    }
}
