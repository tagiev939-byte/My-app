import Foundation
import simd

// MARK: - Layout (world units, restaurant at the origin, street towards +Z)

enum Layout {
    static let stationX: [Float] = [-3, -1, 1, 3]
    static let stationZ: Float = -1.85
    static let windowX: [Float] = [0, -2.4, 2.4]
    static let queueZ0: Float = 2.05
    static let queueStep: Float = 0.72
    static let maxQueue = 5
    static let laneIn: Float = 5.45
    static let laneOut: Float = 6.1
    static let laneWalk: Float = 5.8
    static let spawnX: Float = 13
    static let seats: [SIMD2<Float>] = [SIMD2(-7.0, 2.6), SIMD2(-7.0, 3.85), SIMD2(7.0, 2.6), SIMD2(7.0, 3.85)]
    static let tables: [SIMD2<Float>] = [SIMD2(-7.0, 3.22), SIMD2(7.0, 3.22)]
    static let courierSpot = SIMD2<Float>(5.15, 2.1)

    static func slot(_ w: Int, _ k: Int) -> SIMD2<Float> {
        SIMD2(windowX[w], queueZ0 + Float(k) * queueStep)
    }

    static func seatsOpen(decor: Int) -> Int { decor >= 4 ? 4 : (decor >= 3 ? 2 : 0) }
}

// MARK: - Runtime entities

enum CState {
    case toQueue, queued, toSeat, sitting, leaving, passing
}

enum Mood {
    case none, happy, angry
}

final class Customer {
    let id: Int
    var pos: SIMD2<Float>
    var path: [SIMD2<Float>] = []
    var speed: Float
    var state: CState
    var window = -1
    var slot = -1
    var order: [Dish] = []
    var collected: [Dish] = []
    var collectTimer = 0.0
    var patience = 30.0
    var maxPatience = 30.0
    var serveTimer = -1.0
    var vip = false
    let look: Int
    var bag = false
    var mood: Mood = .none
    var moodTime = 0.0
    var seat = -1
    var sitTimer = 0.0
    var yaw: Float = 0
    var moving = false

    init(id: Int, pos: SIMD2<Float>, speed: Float, state: CState, look: Int) {
        self.id = id
        self.pos = pos
        self.speed = speed
        self.state = state
        self.look = look
    }

    var waiting: Bool { state == .toQueue || state == .queued }
    var atCounter: Bool { state == .queued && slot == 0 && path.isEmpty }
}

final class Delivery {
    var needs: [(Dish, Int)]
    var got: [Dish: Int] = [:]
    var timeLeft: Double
    let total: Double
    let reward: Double
    var phase = 0          // 0 arriving, 1 waiting, 2 leaving
    var pos: SIMD2<Float>
    var path: [SIMD2<Float>]
    var collectTimer = 0.0
    var yaw: Float = -Float.pi / 2

    init(needs: [(Dish, Int)], time: Double, reward: Double) {
        self.needs = needs
        self.timeLeft = time
        self.total = time
        self.reward = reward
        self.pos = SIMD2(16, 7.3)
        self.path = [SIMD2(Layout.courierSpot.x + 0.6, 7.3), SIMD2(Layout.courierSpot.x, Layout.courierSpot.y + 0.4)]
    }

    var done: Bool { needs.allSatisfy { got[$0.0, default: 0] >= $0.1 } }
    var delivered: Int { needs.reduce(0) { $0 + min($1.1, got[$1.0, default: 0]) } }
    var required: Int { needs.reduce(0) { $0 + $1.1 } }
}

final class LocRuntime {
    var customers: [Customer] = []
    var queues: [[Customer]] = [[], [], []]
    var spawnAccum = 0.6
    var passAccum = 0.0
    var delivery: Delivery?
    var deliveryCooldown = 45.0
    var criticCooldown = 150.0
    var seats: [Int] = [-1, -1, -1, -1]
    var rateEMA = 0.0
    var secondIncome = 0.0
}

enum SimEvent {
    case produced(loc: Int, station: Int)
    case collected(loc: Int, station: Int, window: Int)
    case paid(loc: Int, window: Int, amount: Double, vip: Bool)
    case angry(loc: Int, vip: Bool)
    case deliveryArrived(loc: Int)
    case deliveryCollected(loc: Int, station: Int)
    case deliveryDone(loc: Int, reward: Double)
    case deliveryFailed(loc: Int)
    case critic(loc: Int)
}

// MARK: - Simulation

final class Simulation {
    var s: GameState
    var runtimes: [LocRuntime]
    var events: [SimEvent] = []
    var rainTime = 0.0
    var rainCooldown = 200.0
    private var nextId = 1
    private var secondAccum = 0.0
    private var secondIncome = 0.0
    private var historyAccum = 0.0
    var buckets = [Double](repeating: 0, count: 30)
    private var bucketIndex = 0

    init(state: GameState) {
        s = state
        runtimes = Catalog.locations.map { _ in LocRuntime() }
    }

    var raining: Bool { rainTime > 0 }
    var incomePerMinute: Double { buckets.reduce(0, +) * 2 }

    func reset(_ state: GameState) {
        s = state
        runtimes = Catalog.locations.map { _ in LocRuntime() }
        events.removeAll()
        buckets = [Double](repeating: 0, count: 30)
    }

    // MARK: Step

    func step(_ dt: Double) {
        s.playTime += dt
        s.dayTime = (s.dayTime + dt / Rules.dayLength).truncatingRemainder(dividingBy: 1)
        if s.boostTime > 0 { s.boostTime = max(0, s.boostTime - dt) }
        if s.boostCooldown > 0 { s.boostCooldown = max(0, s.boostCooldown - dt) }

        if rainTime > 0 {
            rainTime -= dt
        } else {
            rainCooldown -= dt
            if rainCooldown <= 0 {
                rainTime = Double.random(in: 50...90)
                rainCooldown = Double.random(in: 300...520)
            }
        }

        secondAccum += dt
        while secondAccum >= 1 {
            secondAccum -= 1
            s.incomeRate = s.incomeRate * 0.95 + secondIncome * 0.05
            secondIncome = 0
            bucketIndex = (bucketIndex + 1) % buckets.count
            buckets[bucketIndex] = 0
            for rt in runtimes {
                rt.rateEMA = rt.rateEMA * 0.95 + rt.secondIncome * 0.05
                rt.secondIncome = 0
            }
            historyAccum += 1
            if historyAccum >= 30 {
                historyAccum = 0
                s.history.append(incomePerMinute)
                if s.history.count > 40 { s.history.removeFirst(s.history.count - 40) }
            }
        }

        for i in 0..<s.locations.count where s.locations[i].unlocked {
            stepLocation(i, dt)
        }
    }

    // MARK: Location

    private func stepLocation(_ i: Int, _ dt: Double) {
        let info = Catalog.locations[i]
        let rt = runtimes[i]

        // Kitchen
        for j in 0..<4 {
            var st = s.locations[i].stations[j]
            guard st.level > 0 else { continue }
            if st.stock < Rules.capacity(st.level) {
                st.progress += dt * Rules.rate(info.dishes[j], level: st.level, cooks: st.cooks)
                if st.progress >= 1 {
                    st.progress = 0
                    st.stock += 1
                    events.append(.produced(loc: i, station: j))
                }
            }
            s.locations[i].stations[j] = st
        }

        // Street
        rt.spawnAccum += dt * visitorRate(i)
        while rt.spawnAccum >= 1 {
            rt.spawnAccum -= 1
            spawnVisitor(i, vip: false)
        }
        rt.passAccum += dt * 0.3 * (raining ? 0.6 : 1) * (Rules.nightFactor(s.dayTime) > 0.5 ? 0.6 : 1)
        while rt.passAccum >= 1 {
            rt.passAccum -= 1
            spawnPasser(i)
        }

        rt.criticCooldown -= dt
        if rt.criticCooldown <= 0 {
            rt.criticCooldown = Double.random(in: 160...260)
            if s.tutorial >= 90, spawnVisitor(i, vip: true) { events.append(.critic(loc: i)) }
        }

        updateCustomers(i, dt)
        serveWindows(i, dt)
        updateDelivery(i, dt)
    }

    func visitorRate(_ i: Int) -> Double {
        let L = s.locations[i]
        var r = 0.21 * (1 + 0.12 * Double(L.marketing)) * (1 + 0.08 * Double(s.level(.ads))) * (1 + 0.03 * Double(L.decor))
        r *= 0.55 + 0.1 * L.rating
        r *= Rules.dayFactor(s.dayTime)
        if raining { r *= 0.75 }
        return r
    }

    @discardableResult
    private func spawnVisitor(_ i: Int, vip: Bool) -> Bool {
        let rt = runtimes[i]
        let L = s.locations[i]
        guard rt.customers.count < 46 else { return false }
        let available = (0..<4).filter { L.stations[$0].level > 0 }
        guard !available.isEmpty else { return false }
        var best = -1
        for w in 0..<L.windows where rt.queues[w].count < Layout.maxQueue {
            if best < 0 || rt.queues[w].count < rt.queues[best].count { best = w }
        }
        guard best >= 0 else {
            spawnPasser(i)
            return false
        }
        let side: Float = Bool.random() ? 1 : -1
        let c = Customer(id: nextId, pos: SIMD2(side * Layout.spawnX, Layout.laneIn),
                         speed: Float.random(in: 1.45...1.95), state: .toQueue, look: Int.random(in: 0...100_000))
        nextId += 1
        c.vip = vip
        c.window = best
        c.slot = rt.queues[best].count
        rt.queues[best].append(c)
        c.order = makeOrder(i, available: available, vip: vip)
        c.maxPatience = (vip ? 36 : 30) * (1 + 0.1 * Double(L.decor))
        c.patience = c.maxPatience
        c.path = [SIMD2(Layout.windowX[best] + side * 0.15, Layout.laneIn), Layout.slot(best, c.slot)]
        rt.customers.append(c)
        return true
    }

    private func spawnPasser(_ i: Int) {
        let rt = runtimes[i]
        guard rt.customers.count < 46 else { return }
        let side: Float = Bool.random() ? 1 : -1
        let z = Layout.laneWalk + Float.random(in: -0.35...0.35)
        let c = Customer(id: nextId, pos: SIMD2(side * Layout.spawnX, z), speed: Float.random(in: 1.3...2.0),
                         state: .passing, look: Int.random(in: 0...100_000))
        nextId += 1
        c.path = [SIMD2(-side * Layout.spawnX, z)]
        rt.customers.append(c)
    }

    private func makeOrder(_ i: Int, available: [Int], vip: Bool) -> [Dish] {
        let dishes = available.map { Catalog.locations[i].dishes[$0] }
        if vip {
            let sorted = dishes.sorted { $0.basePrice > $1.basePrice }
            return Array(sorted.prefix(3))
        }
        let roll = Double.random(in: 0..<1)
        let count = roll < 0.55 ? 1 : (roll < 0.9 ? 2 : 3)
        let total = dishes.reduce(0) { $0 + $1.popularity }
        var out: [Dish] = []
        for _ in 0..<count {
            var x = Double.random(in: 0..<total)
            var pick = dishes[dishes.count - 1]
            for d in dishes {
                x -= d.popularity
                if x <= 0 {
                    pick = d
                    break
                }
            }
            out.append(pick)
        }
        return out
    }

    // MARK: Customers

    private func updateCustomers(_ i: Int, _ dt: Double) {
        let rt = runtimes[i]
        var removed: [Int] = []
        for c in rt.customers {
            if !c.path.isEmpty {
                let target = c.path[0]
                let d = target - c.pos
                let dist = simd_length(d)
                let stepLen = c.speed * Float(dt) * (raining && c.state == .passing ? 1.25 : 1)
                if dist <= stepLen {
                    c.pos = target
                    c.path.removeFirst()
                } else {
                    c.pos += d / dist * stepLen
                }
                if dist > 0.001 {
                    let want = atan2(-d.x, -d.y)
                    c.yaw = lerpAngle(c.yaw, want, min(1, Float(dt) * 12))
                }
                c.moving = true
            } else {
                c.moving = false
            }
            if c.moodTime > 0 {
                c.moodTime -= dt
                if c.moodTime <= 0 { c.mood = .none }
            }

            switch c.state {
            case .toQueue, .queued:
                c.patience -= dt * (c.vip ? 1.1 : 1)
                if c.path.isEmpty {
                    c.state = .queued
                    c.yaw = lerpAngle(c.yaw, 0, min(1, Float(dt) * 8))
                }
                if c.patience <= 0 { leaveAngry(i, c) }
            case .toSeat:
                if c.path.isEmpty {
                    c.state = .sitting
                    c.sitTimer = Double.random(in: 6...10)
                    let table = c.seat < 2 ? Layout.tables[0] : Layout.tables[1]
                    let d = table - c.pos
                    c.yaw = atan2(-d.x, -d.y)
                }
            case .sitting:
                c.sitTimer -= dt
                if c.sitTimer <= 0 {
                    if c.seat >= 0 { rt.seats[c.seat] = -1 }
                    c.seat = -1
                    c.state = .leaving
                    let side: Float = c.pos.x > 0 ? 1 : -1
                    c.path = [SIMD2(c.pos.x, Layout.laneOut), SIMD2(side * Layout.spawnX, Layout.laneOut)]
                }
            case .leaving, .passing:
                if c.path.isEmpty { removed.append(c.id) }
            }
        }
        if !removed.isEmpty {
            rt.customers.removeAll { removed.contains($0.id) }
        }
    }

    private func lerpAngle(_ a: Float, _ b: Float, _ t: Float) -> Float {
        var d = b - a
        while d > Float.pi { d -= 2 * Float.pi }
        while d < -Float.pi { d += 2 * Float.pi }
        return a + d * t
    }

    private func removeFromQueue(_ i: Int, _ c: Customer) {
        let rt = runtimes[i]
        guard c.window >= 0, let idx = rt.queues[c.window].firstIndex(where: { $0 === c }) else { return }
        rt.queues[c.window].remove(at: idx)
        for (k, q) in rt.queues[c.window].enumerated() where q.slot != k {
            q.slot = k
            let target = Layout.slot(c.window, k)
            if q.path.isEmpty {
                q.path = [target]
            } else {
                q.path[q.path.count - 1] = target
            }
        }
    }

    private func exitPath(from c: Customer) -> [SIMD2<Float>] {
        let wx = Layout.windowX[max(0, c.window)]
        let side: Float = wx > 0.1 ? 1 : (wx < -0.1 ? -1 : (Bool.random() ? 1 : -1))
        let x = wx + side * 1.05
        return [SIMD2(x, c.pos.y + 0.35), SIMD2(x, Layout.laneOut), SIMD2(side * Layout.spawnX, Layout.laneOut)]
    }

    private func leaveAngry(_ i: Int, _ c: Customer) {
        let L = s.locations[i]
        for d in c.collected {
            if let j = Catalog.locations[i].dishes.firstIndex(of: d) {
                s.locations[i].stations[j].stock = min(Rules.capacity(L.stations[j].level), s.locations[i].stations[j].stock + 1)
            }
        }
        c.collected.removeAll()
        removeFromQueue(i, c)
        c.state = .leaving
        c.mood = .angry
        c.moodTime = 2.2
        c.path = exitPath(from: c)
        s.angry += 1
        rate(i, target: c.vip ? 0.5 : 1.5, weight: c.vip ? 0.25 : 0.06)
        events.append(.angry(loc: i, vip: c.vip))
    }

    private func rate(_ i: Int, target: Double, weight: Double) {
        let r = s.locations[i].rating
        s.locations[i].rating = min(5, max(1, r + (target - r) * weight))
    }

    // MARK: Service

    private func serveWindows(_ i: Int, _ dt: Double) {
        let rt = runtimes[i]
        let info = Catalog.locations[i]
        for w in 0..<s.locations[i].windows {
            guard let c = rt.queues[w].first, c.atCounter else { continue }
            if c.collected.count < c.order.count {
                c.collectTimer -= dt
                guard c.collectTimer <= 0 else { continue }
                var pending = c.order
                for d in c.collected {
                    if let k = pending.firstIndex(of: d) { pending.remove(at: k) }
                }
                for d in pending {
                    guard let j = info.dishes.firstIndex(of: d), s.locations[i].stations[j].stock > 0 else { continue }
                    s.locations[i].stations[j].stock -= 1
                    c.collected.append(d)
                    c.collectTimer = 0.25
                    events.append(.collected(loc: i, station: j, window: w))
                    break
                }
            } else {
                if c.serveTimer < 0 { c.serveTimer = Rules.serveTime(s.locations[i].cashier) }
                c.serveTimer -= dt
                if c.serveTimer <= 0 { pay(i, w, c) }
            }
        }
    }

    private func pay(_ i: Int, _ w: Int, _ c: Customer) {
        let info = Catalog.locations[i]
        let L = s.locations[i]
        var total = 0.0
        for d in c.order {
            let j = info.dishes.firstIndex(of: d) ?? 0
            total += Rules.price(d, L.stations[j].level)
        }
        let frac = max(0, c.patience / c.maxPatience)
        let tip = 0.3 * frac * (1 + 0.1 * Double(L.decor))
        var amount = total * (1 + tip) * s.priceMult
        if c.vip { amount *= 4 }
        earn(i, amount)
        s.locations[i].served += 1
        s.served += 1
        if c.vip {
            s.locations[i].rating = min(5, L.rating + 0.4)
        } else {
            rate(i, target: frac > 0.5 ? 5 : (frac > 0.25 ? 4.3 : 3.4), weight: 0.05)
        }
        events.append(.paid(loc: i, window: w, amount: amount, vip: c.vip))

        removeFromQueue(i, c)
        c.bag = true
        c.mood = .happy
        c.moodTime = 1.6
        let rt = runtimes[i]
        let open = Layout.seatsOpen(decor: L.decor)
        if open > 0, Double.random(in: 0..<1) < 0.45,
           let seat = (0..<open).filter({ rt.seats[$0] < 0 }).randomElement() {
            rt.seats[seat] = c.id
            c.seat = seat
            c.state = .toSeat
            let wx = Layout.windowX[w]
            let target = Layout.seats[seat]
            let side: Float = target.x > 0 ? 1 : -1
            c.path = [SIMD2(wx + side * 1.05, c.pos.y + 0.4), SIMD2(target.x, c.pos.y + 0.4), target]
        } else {
            c.state = .leaving
            c.path = exitPath(from: c)
        }
    }

    func earn(_ i: Int, _ amount: Double) {
        s.money += amount
        s.totalEarned += amount
        s.lifetimeEarned += amount
        s.locations[i].earned += amount
        secondIncome += amount
        buckets[bucketIndex] += amount
        runtimes[i].secondIncome += amount
    }

    // MARK: Deliveries

    private func updateDelivery(_ i: Int, _ dt: Double) {
        let rt = runtimes[i]
        let info = Catalog.locations[i]
        guard let d = rt.delivery else {
            rt.deliveryCooldown -= dt
            if rt.deliveryCooldown <= 0 {
                rt.deliveryCooldown = Double.random(in: 70...120)
                if s.tutorial >= 90 { makeDelivery(i) }
            }
            return
        }
        if !d.path.isEmpty {
            let target = d.path[0]
            let v = target - d.pos
            let dist = simd_length(v)
            let stepLen = Float(dt) * 5.5
            if dist <= stepLen {
                d.pos = target
                d.path.removeFirst()
            } else {
                d.pos += v / dist * stepLen
                d.yaw = atan2(-v.x, -v.y)
            }
        }
        switch d.phase {
        case 0:
            if d.path.isEmpty {
                d.phase = 1
                events.append(.deliveryArrived(loc: i))
            }
        case 1:
            d.timeLeft -= dt
            d.collectTimer -= dt
            if d.collectTimer <= 0 {
                d.collectTimer = 0.4
                for (dish, need) in d.needs where d.got[dish, default: 0] < need {
                    guard let j = info.dishes.firstIndex(of: dish), s.locations[i].stations[j].stock > 0 else { continue }
                    s.locations[i].stations[j].stock -= 1
                    d.got[dish, default: 0] += 1
                    events.append(.deliveryCollected(loc: i, station: j))
                    break
                }
            }
            if d.done {
                let reward = d.reward * (1 + 0.25 * Double(s.level(.courier))) * (s.boostTime > 0 ? 2 : 1)
                earn(i, reward)
                s.deliveries += 1
                events.append(.deliveryDone(loc: i, reward: reward))
                d.phase = 2
                d.path = [SIMD2(Layout.courierSpot.x + 0.6, 7.3), SIMD2(-16, 7.3)]
            } else if d.timeLeft <= 0 {
                events.append(.deliveryFailed(loc: i))
                d.phase = 2
                d.path = [SIMD2(Layout.courierSpot.x + 0.6, 7.3), SIMD2(-16, 7.3)]
            }
        default:
            if d.path.isEmpty { rt.delivery = nil }
        }
    }

    private func makeDelivery(_ i: Int) {
        let info = Catalog.locations[i]
        let L = s.locations[i]
        let open = (0..<4).filter { L.stations[$0].level > 0 && L.stations[$0].cooks > 0 }
        guard !open.isEmpty else { return }
        let picks = Array(open.shuffled().prefix(open.count > 1 ? 2 : 1))
        var needs: [(Dish, Int)] = []
        var value = 0.0
        for j in picks {
            let st = L.stations[j]
            let r = Rules.rate(info.dishes[j], level: st.level, cooks: st.cooks)
            let n = max(3, min(14, Int(r * 18)))
            needs.append((info.dishes[j], n))
            value += Rules.price(info.dishes[j], st.level) * Double(n)
        }
        runtimes[i].delivery = Delivery(needs: needs, time: 90, reward: (value * 2.5 * s.priceMult / (s.boostTime > 0 ? 2 : 1)).rounded())
    }

    // MARK: Player actions

    /// Tapping a station helps the cooks: a burst of progress.
    func tap(_ i: Int, _ j: Int) -> Bool {
        var st = s.locations[i].stations[j]
        guard st.level > 0, st.stock < Rules.capacity(st.level) else { return false }
        st.progress += 0.34
        if st.progress >= 1 {
            st.progress = 0
            st.stock += 1
            events.append(.produced(loc: i, station: j))
        }
        s.locations[i].stations[j] = st
        return true
    }

    func working(_ i: Int, _ j: Int) -> Bool {
        let st = s.locations[i].stations[j]
        return st.level > 0 && st.cooks > 0 && st.stock < Rules.capacity(st.level)
    }

    /// Prewarm a location so screenshots and fresh loads show a lively street.
    func warmUp(seconds: Double) {
        let steps = Int(seconds * 30)
        for _ in 0..<steps { step(1.0 / 30.0) }
        events.removeAll()
    }
}
