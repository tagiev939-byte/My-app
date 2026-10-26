import SwiftUI
import SceneKit
import UIKit

enum SheetKind: String, Identifiable {
    case upgrades, city, empire, quests, menu
    var id: String { rawValue }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let icon: String
    let tint: Color
    var big = false

    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

struct OfflineReport: Identifiable, Equatable {
    let id = UUID()
    let amount: Double
    let seconds: Double
}

struct DailyReport: Identifiable, Equatable {
    let id = UUID()
    let streak: Int
    let amount: Double
}

struct DeliveryHUD: Equatable {
    var delivered = 0
    var required = 0
    var timeLeft = 0.0
    var total = 1.0
    var reward = 0.0
    var waiting = false
}

struct HUDState: Equatable {
    var money = 0.0
    var income = 0.0
    var rating = 4.2
    var clock = "06:00"
    var night = false
    var rush = false
    var raining = false
    var loc = 0
    var boostTime = 0.0
    var boostCooldown = 0.0
    var delivery: DeliveryHUD?
    var questsReady = 0
    var canUpgrade = false
    var tutorial = 0
    var queue = 0
    var stars = 0
    var empireReady = false
}

enum BulkMode: Int, CaseIterable {
    case one = 1, ten = 10, max = 0

    var title: String {
        switch self {
        case .one: return "×1"
        case .ten: return "×10"
        case .max: return "MAX"
        }
    }
}

private final class LinkProxy: NSObject {
    weak var owner: GameController?
    init(_ o: GameController) { owner = o }
    @objc func tick(_ l: CADisplayLink) { owner?.frame(l) }
}

final class GameController: ObservableObject {
    @Published var selected: Pick?
    @Published var toast: Toast?
    @Published var sheet: SheetKind?
    @Published var showTitle: Bool
    @Published var offline: OfflineReport?
    @Published var daily: DailyReport?
    @Published var hud = HUDState()
    @Published var icons: [String: UIImage] = [:]
    @Published var tick = 0
    @Published var fade = false
    @Published var bulk: BulkMode = .one
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

    let sim: Simulation
    let renderer = SceneRenderer()
    let scenario: String?
    private(set) var hasSave: Bool
    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var hudAccum = 0.0
    private var saveAccum = 0.0
    private var questAccum = 0.0
    private var pendingOffline: OfflineReport?
    private var iconQueue: [Dish] = Dish.allCases
    private lazy var iconRenderer = IconRenderer()
    private var lastCoinSound: Double = 0
    private var lastSizzle: Double = 0
    private var wasRush = false
    private var wasRaining = false
    private var tutorialTaps = 0
    private var giftCooldown = 45.0
    private var lastFullHint = -10.0
    private var lastDrag: CGPoint = .zero
    private var panSamples: [(t: CFTimeInterval, d: SIMD3<Float>)] = []
    private weak var view: SCNView?

    var s: GameState { sim.s }
    var loc: Int { sim.s.current }
    var info: LocationInfo { Catalog.locations[sim.s.current] }
    var L: LocationState { sim.s.locations[sim.s.current] }

    // MARK: Init

    init() {
        let d = UserDefaults.standard
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-scenario"), i + 1 < args.count {
            scenario = args[i + 1]
        } else {
            scenario = d.string(forKey: "scenario")
        }
        soundOn = d.object(forKey: "soundOn") as? Bool ?? true
        hapticsOn = d.object(forKey: "hapticsOn") as? Bool ?? true
        musicOn = d.object(forKey: "musicOn") as? Bool ?? true
        highQuality = d.object(forKey: "highQuality") as? Bool ?? (ProcessInfo.processInfo.physicalMemory > 3_500_000_000)

        var state: GameState
        var report: OfflineReport?
        var saved = false
        if let sc = scenario {
            state = GameController.scenarioState(sc)
        } else if var loaded = GameController.load() {
            saved = true
            let away = Date().timeIntervalSince1970 - loaded.lastActive
            if away > 90 && loaded.incomeRate > 0.01 {
                let secs = min(away, loaded.offlineHours * 3600)
                let amount = (loaded.incomeRate * secs * 0.5).rounded()
                if amount >= 1 {
                    loaded.money += amount
                    loaded.totalEarned += amount
                    loaded.lifetimeEarned += amount
                    report = OfflineReport(amount: amount, seconds: away)
                }
            }
            state = loaded
        } else {
            state = GameState.fresh()
        }
        sim = Simulation(state: state)
        hasSave = saved
        pendingOffline = report
        showTitle = scenario == nil || scenario == "title"

        Sound.shared.enabled = soundOn
        Haptics.enabled = hapticsOn
        if scenario == nil { Sound.shared.setMusic(musicOn) }

        fillQuests()
        sim.warmUp(seconds: scenario == nil ? 25 : 40)
        renderer.highQuality = highQuality
        renderer.setup()
        renderer.load(sim.s.current, sim: sim)
        wasRush = Rules.isRush(sim.s.dayTime)
        if showTitle {
            renderer.rig.focus(SIMD3(0, 0, 0.6), distance: 15, yaw: -0.35)
            renderer.rig.snap()
        }

        publishHUD()
        let proxy = LinkProxy(self)
        let l = CADisplayLink(target: proxy, selector: #selector(LinkProxy.tick(_:)))
        l.preferredFramesPerSecond = 60
        l.add(to: .main, forMode: .common)
        link = l

        if let sc = scenario { applyScenario(sc) }
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
        // 2x instead of native 3x: half the pixels, same sharpness after MSAA.
        v.contentScaleFactor = min(UIScreen.main.scale, 2)
        renderer.view = v
        renderer.prewarm()
    }

    // MARK: Loop

    fileprivate func frame(_ l: CADisplayLink) {
        let now = l.timestamp
        var dt = lastTime == 0 ? 1.0 / 60.0 : now - lastTime
        lastTime = now
        dt = min(max(dt, 0), 0.1)

        sim.step(dt)
        handleEvents()
        if !showTitle && sim.s.tutorial >= 90 && scenario == nil {
            giftCooldown -= dt
            if giftCooldown <= 0 {
                giftCooldown = Double.random(in: 80...150)
                renderer.spawnGift()
            }
        }
        renderer.update(sim, dt: dt)
        processIcons()

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

    private func processIcons() {
        guard !iconQueue.isEmpty else { return }
        for _ in 0..<2 {
            guard !iconQueue.isEmpty else { break }
            let d = iconQueue.removeFirst()
            icons[d.iconKey] = iconRenderer.render(renderer.dishes.node(d), size: 150, yaw: 0.5, pitch: 0.5)
        }
        if iconQueue.isEmpty {
            renderer.icons = icons
            renderer.iconsReady(sim)
        }
    }

    func publishHUD() {
        updateTutorial()
        let st = sim.s
        var h = HUDState()
        h.money = st.money
        h.income = sim.incomePerMinute
        h.rating = L.rating
        h.clock = Rules.clock(st.dayTime)
        h.night = Rules.nightFactor(st.dayTime) > 0.5
        h.rush = Rules.isRush(st.dayTime)
        h.raining = sim.raining
        h.loc = st.current
        h.boostTime = st.boostTime.rounded(.up)
        h.boostCooldown = st.boostCooldown.rounded(.up)
        h.tutorial = st.tutorial
        h.stars = st.stars
        h.questsReady = st.quests.filter { $0.done }.count
        h.queue = sim.runtimes[loc].queues.reduce(0) { $0 + $1.count }
        h.empireReady = GlobalUpgrade.allCases.contains { u in
            let l = st.level(u)
            return l < u.maxLevel && st.money >= u.cost(l)
        } || st.potentialStars > 0
        h.canUpgrade = (0..<4).contains { j in
            let stn = L.stations[j]
            if stn.level == 0 { return st.money >= info.stationCosts[j] }
            return stn.level < Rules.maxLevel && st.money >= Rules.upgradeCost(info.dishes[j], stn.level)
        }
        if let d = sim.runtimes[loc].delivery, d.phase < 2 {
            h.delivery = DeliveryHUD(delivered: d.delivered, required: d.required, timeLeft: d.timeLeft.rounded(.up),
                                     total: d.total, reward: d.reward, waiting: d.phase == 1)
        }
        if h != hud { hud = h }
        if selected != nil || sheet != nil { tick &+= 1 }

        // Rating quests follow the best restaurant.
        let best = st.locations.filter { $0.unlocked }.map { $0.rating }.max() ?? 0
        for i in sim.s.quests.indices where sim.s.quests[i].kind == .rating && !sim.s.quests[i].done {
            sim.s.quests[i].progress = best
            if sim.s.quests[i].done { questCompleted(sim.s.quests[i]) }
        }

        // Day events
        let rush = Rules.isRush(st.dayTime)
        if rush && !wasRush && !showTitle && st.tutorial >= 90 {
            Sound.shared.play(.bell, volume: 0.6)
            showToast("Час пик! Клиентов почти вдвое больше", icon: "flame.fill", tint: Color(hex: 0xFF8A50), big: true)
        }
        wasRush = rush
        if sim.raining && !wasRaining && !showTitle && st.tutorial >= 90 {
            showToast("Пошёл дождь — гостей меньше, зато все с зонтами", icon: "cloud.rain.fill", tint: Color(hex: 0x90CAF9))
        }
        wasRaining = sim.raining
    }

    // MARK: Events

    private func handleEvents() {
        guard !sim.events.isEmpty else { return }
        let events = sim.events
        sim.events.removeAll()
        for e in events {
            renderer.handle(e, sim: sim)
            switch e {
            case .produced:
                break
            case .collected:
                break
            case .paid(let l, _, let amount, let vip):
                progressQuests(.serve, 1)
                progressQuests(.earn, amount)
                if l == loc && !showTitle {
                    if vip {
                        Sound.shared.play(.cash, volume: 0.8)
                        Haptics.success()
                        showToast("Критик в восторге! Рейтинг растёт", icon: "star.circle.fill", tint: Color(hex: 0xFFD54F))
                    } else if sim.s.playTime - lastCoinSound > 0.12 {
                        lastCoinSound = sim.s.playTime
                        Sound.shared.play(.coin, volume: 0.3)
                    }
                }
            case .angry(let l, let vip):
                if l == loc && !showTitle {
                    Sound.shared.play(.angry, volume: 0.45)
                    if vip {
                        Haptics.error()
                        showToast("Критик ушёл недовольным… Рейтинг упал", icon: "star.slash.fill", tint: Pal.bad)
                    }
                }
            case .critic(let l):
                if l == loc && !showTitle {
                    Sound.shared.play(.bell, volume: 0.7)
                    showToast("Пришёл ресторанный критик! Обслужите его быстрее", icon: "crown.fill",
                              tint: Color(hex: 0xFFD54F), big: true)
                }
            case .deliveryArrived(let l):
                if l == loc && !showTitle {
                    Sound.shared.play(.bell, volume: 0.6)
                    showToast("Курьер ждёт заказ на доставку", icon: "scooter", tint: Color(hex: 0x81C784))
                }
            case .deliveryCollected:
                break
            case .deliveryDone(let l, let reward):
                progressQuests(.delivery, 1)
                progressQuests(.earn, reward)
                if l == loc && !showTitle {
                    Sound.shared.play(.cash, volume: 0.8)
                    Haptics.success()
                    showToast("Доставка выполнена! \(Fmt.gain(reward))", icon: "checkmark.seal.fill", tint: Pal.good)
                }
            case .deliveryFailed(let l):
                if l == loc && !showTitle {
                    Sound.shared.play(.error, volume: 0.4)
                    showToast("Курьер не дождался заказа", icon: "clock.badge.xmark", tint: .orange)
                }
            }
        }
    }

    // MARK: Toasts

    func showToast(_ text: String, icon: String = "info.circle.fill", tint: Color = .white, big: Bool = false) {
        let t = Toast(text: text, icon: icon, tint: tint, big: big)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + (big ? 3.2 : 2.6)) { [weak self] in
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
        Sound.shared.play(.whoosh, volume: 0.7)
        withAnimation(.easeInOut(duration: 0.45)) { showTitle = false }
        renderer.rig.reset()
        if let r = pendingOffline {
            pendingOffline = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self?.offline = r }
            }
        } else {
            checkDaily(after: 0.9)
        }
        publishHUD()
    }

    func collectOffline() {
        Sound.shared.play(.cash)
        Haptics.success()
        renderer.celebrate()
        withAnimation { offline = nil }
        checkDaily(after: 0.8)
    }

    // MARK: Daily bonus

    static let dailyMultipliers: [Double] = [1, 1.5, 2, 2.5, 3, 4, 6]

    private static var today: Int {
        Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
    }

    private func checkDaily(after delay: Double) {
        guard scenario == nil || scenario == "daily", sim.s.tutorial >= 90, daily == nil else { return }
        let day = GameController.today
        guard day != sim.s.bonusDay else { return }
        let streak = sim.s.bonusDay == day - 1 ? min(7, sim.s.bonusStreak + 1) : 1
        let base = max(150 * Catalog.locations[loc].tier, sim.incomePerMinute * 4)
        let amount = GameController.nice(base * GameController.dailyMultipliers[streak - 1])
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self?.daily = DailyReport(streak: streak, amount: amount) }
        }
    }

    func claimDaily() {
        guard let d = daily else { return }
        sim.s.bonusDay = GameController.today
        sim.s.bonusStreak = d.streak
        sim.s.money += d.amount
        sim.s.totalEarned += d.amount
        sim.s.lifetimeEarned += d.amount
        Sound.shared.play(.cash)
        Haptics.success()
        renderer.celebrate()
        withAnimation { daily = nil }
        publishHUD()
        save()
    }

    // MARK: Input

    func select(_ p: Pick?) {
        selected = p
        renderer.setSelection(p)
        tick &+= 1
    }

    func handleTap(_ p: CGPoint) {
        guard !showTitle, !fade else { return }
        guard let pick = renderer.pick(p) else {
            if selected != nil { select(nil) }
            return
        }
        switch pick {
        case .gift:
            collectGift()
        case .station(let j):
            if selected != pick {
                select(pick)
            }
            helpCook(j)
        case .locked, .counter, .courier:
            if selected == pick {
                select(nil)
            } else {
                select(pick)
                Sound.shared.play(.tap, volume: 0.6)
                Haptics.soft(0.4)
            }
        }
        publishHUD()
    }

    func collectGift() {
        guard renderer.collectGift() != nil else { return }
        let reward = GameController.nice(max(80 * info.tier, sim.incomePerMinute * 1.5))
        sim.s.money += reward
        sim.s.totalEarned += reward
        sim.s.lifetimeEarned += reward
        progressQuests(.earn, reward)
        Sound.shared.play(.pop, volume: 0.8)
        Sound.shared.play(.cash, volume: 0.7)
        Haptics.success()
        showToast("Подарок от фанатов: \(Fmt.gain(reward))!", icon: "gift.fill", tint: Color(hex: 0xFF80AB))
        publishHUD()
    }

    func helpCook(_ j: Int) {
        tutorialTaps += 1
        if sim.tap(loc, j) {
            renderer.tapStation(j)
            progressQuests(.tap, 1)
            if sim.s.playTime - lastSizzle > 0.06 {
                lastSizzle = sim.s.playTime
                Sound.shared.play(.sizzle, volume: 0.55)
            }
            Haptics.soft(0.45)
        } else {
            let st = L.stations[j]
            if st.level > 0, st.stock >= Rules.capacity(st.level), sim.s.playTime - lastFullHint > 1.2 {
                lastFullHint = sim.s.playTime
                renderer.floatText("Всё готово!", at: SIMD3(Layout.stationX[j], 2.3, Layout.stationZ), color: 0x9CE07A)
            }
            Sound.shared.play(.tap, volume: 0.45)
            Haptics.soft(0.3)
        }
    }

    func dragBegan(start: CGPoint, current: CGPoint) {
        guard !showTitle else { return }
        renderer.rig.velocity = .zero
        panSamples.removeAll()
        lastDrag = start
        dragChanged(current)
    }

    func dragChanged(_ p: CGPoint) {
        guard !showTitle else { return }
        let d = renderer.panCamera(from: lastDrag, to: p)
        lastDrag = p
        let now = CACurrentMediaTime()
        panSamples.append((now, d))
        panSamples.removeAll { now - $0.t > 0.1 }
    }

    func dragEnded() {
        if let first = panSamples.first, let last = panSamples.last {
            let now = CACurrentMediaTime()
            if now - last.t < 0.06 {
                let span = max(0.016, last.t - first.t + 1.0 / 60.0)
                let sum = panSamples.reduce(SIMD3<Float>.zero) { $0 + $1.d }
                renderer.rig.fling(sum / Float(span))
            }
        }
        panSamples.removeAll()
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

    func resetCamera() {
        renderer.rig.reset()
        Sound.shared.play(.tap, volume: 0.5)
    }

    // MARK: Station actions

    func upgradeInfo(_ j: Int, mode: BulkMode? = nil) -> (levels: Int, cost: Double) {
        let st = L.stations[j]
        let d = info.dishes[j]
        let m = mode ?? bulk
        if st.level >= Rules.maxLevel { return (levels: 0, cost: 0) }
        if m == .max {
            let r = Rules.bulk(d, level: st.level, count: 0, money: sim.s.money)
            if r.levels == 0 { return (levels: 1, cost: Rules.upgradeCost(d, st.level)) }
            return (levels: r.levels, cost: r.cost)
        }
        let r = Rules.bulk(d, level: st.level, count: m.rawValue, money: sim.s.money)
        return (levels: r.levels, cost: r.cost)
    }

    func upgradeStation(_ j: Int) {
        let st = L.stations[j]
        guard st.level > 0, st.level < Rules.maxLevel else { return }
        let (levels, cost) = upgradeInfo(j)
        guard levels > 0, sim.s.money >= cost else {
            fail("Не хватает денег: нужно \(Fmt.money(cost))")
            return
        }
        let before = st.level
        sim.s.money -= cost
        sim.s.locations[loc].stations[j].level += levels
        let after = before + levels
        renderer.upgradeEffect(j, levels: levels)
        let crossed = Rules.milestones.filter { $0 > before && $0 <= after }
        if !crossed.isEmpty {
            renderer.milestoneEffect(j)
            Sound.shared.play(.goal, volume: 0.8)
            Haptics.success()
            showToast("\(info.dishes[j].title): скорость ×2!", icon: "hare.fill", tint: Color(hex: 0xFF8A65), big: true)
        } else {
            Sound.shared.play(.upgrade, volume: 0.75)
            Haptics.medium()
        }
        progressQuests(.upgrade, Double(levels))
        renderer.refreshMenu(sim)
        publishHUD()
        tick &+= 1
    }

    func cookCost(_ j: Int) -> Double {
        Rules.cookCost(info.dishes[j])
    }

    func hireCook(_ j: Int) {
        let st = L.stations[j]
        guard st.level > 0, st.cooks < 2 else { return }
        let cost = cookCost(j)
        guard sim.s.money >= cost else {
            fail("Не хватает денег: нужно \(Fmt.money(cost))")
            return
        }
        sim.s.money -= cost
        sim.s.locations[loc].stations[j].cooks += 1
        renderer.refreshStructure(sim, animated: true)
        Sound.shared.play(.unlock, volume: 0.7)
        Haptics.success()
        showToast("Новый повар на станции «\(info.dishes[j].station)»: готовит в 1,8 раза быстрее",
                  icon: "person.fill.badge.plus", tint: Pal.good)
        publishHUD()
        tick &+= 1
    }

    func unlockStation(_ j: Int) {
        guard L.stations[j].level == 0 else { return }
        let cost = info.stationCosts[j]
        guard sim.s.money >= cost else {
            fail("Не хватает денег: нужно \(Fmt.money(cost))")
            return
        }
        sim.s.money -= cost
        sim.s.locations[loc].stations[j] = StationState(level: 1, cooks: 1, stock: 1, progress: 0)
        renderer.refreshStructure(sim, animated: true)
        Sound.shared.play(.unlock, volume: 0.85)
        Haptics.success()
        showToast("В меню новое блюдо: \(info.dishes[j].title)!", icon: "fork.knife.circle.fill", tint: Pal.accent, big: true)
        select(.station(j))
        progressQuests(.upgrade, 1)
        publishHUD()
    }

    // MARK: Counter & hall

    var cashierCost: Double { Rules.cashierCost(info.tier, L.cashier) }
    var windowCost: Double { Rules.windowCost(info.tier, opening: L.windows + 1) }
    var marketingCost: Double { Rules.marketingCost(info.tier, L.marketing) }
    var decorCost: Double { Rules.decorCost(info.tier, L.decor) }

    func upgradeCashier() {
        guard L.cashier < Rules.maxCashier else { return }
        let cost = cashierCost
        guard sim.s.money >= cost else { return fail("Не хватает денег: нужно \(Fmt.money(cost))") }
        sim.s.money -= cost
        sim.s.locations[loc].cashier += 1
        renderer.counterEffect()
        Sound.shared.play(.upgrade, volume: 0.75)
        Haptics.medium()
        progressQuests(.upgrade, 1)
        publishHUD()
        tick &+= 1
    }

    func openWindow() {
        guard L.windows < Rules.maxWindows else { return }
        let cost = windowCost
        guard sim.s.money >= cost else { return fail("Не хватает денег: нужно \(Fmt.money(cost))") }
        sim.s.money -= cost
        sim.s.locations[loc].windows += 1
        renderer.refreshStructure(sim, animated: true)
        Sound.shared.play(.unlock, volume: 0.8)
        Haptics.success()
        showToast("Открыто окно №\(L.windows): очередь пойдёт быстрее", icon: "person.3.fill", tint: Pal.good)
        publishHUD()
        tick &+= 1
    }

    func buyMarketing() {
        guard L.marketing < Rules.maxMarketing else { return }
        let cost = marketingCost
        guard sim.s.money >= cost else { return fail("Не хватает денег: нужно \(Fmt.money(cost))") }
        sim.s.money -= cost
        sim.s.locations[loc].marketing += 1
        Sound.shared.play(.upgrade, volume: 0.75)
        Haptics.medium()
        showToast("Реклама работает: +12% гостей", icon: "megaphone.fill", tint: Color(hex: 0x80DEEA))
        progressQuests(.upgrade, 1)
        publishHUD()
        tick &+= 1
    }

    func buyDecor() {
        guard L.decor < Rules.maxDecor else { return }
        let cost = decorCost
        guard sim.s.money >= cost else { return fail("Не хватает денег: нужно \(Fmt.money(cost))") }
        let name = Rules.decorNames[L.decor]
        sim.s.money -= cost
        sim.s.locations[loc].decor += 1
        renderer.refreshStructure(sim, animated: true)
        Sound.shared.play(.unlock, volume: 0.8)
        Haptics.success()
        showToast("Новый декор: \(name)", icon: "sparkles", tint: Color(hex: 0xF48FB1))
        progressQuests(.upgrade, 1)
        publishHUD()
        tick &+= 1
    }

    // MARK: City

    func locationIncome(_ i: Int) -> Double { sim.runtimes[i].rateEMA * 60 }

    func buyLocation(_ i: Int) {
        guard !sim.s.locations[i].unlocked else { return switchLocation(i) }
        let cost = Catalog.locations[i].unlockCost
        guard sim.s.money >= cost else { return fail("Не хватает денег: нужно \(Fmt.money(cost))") }
        sim.s.money -= cost
        sim.s.locations[i].unlocked = true
        sim.s.locations[i].stations[0] = StationState(level: 1, cooks: 1, stock: 2, progress: 0)
        Sound.shared.play(.goal, volume: 0.9)
        Haptics.success()
        switchLocation(i, celebrate: true)
    }

    func switchLocation(_ i: Int, celebrate: Bool = false) {
        guard sim.s.locations[i].unlocked else { return }
        sheet = nil
        guard i != loc || celebrate else { return }
        Sound.shared.play(.whoosh, volume: 0.7)
        withAnimation(.easeIn(duration: 0.28)) { fade = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            guard let self else { return }
            self.sim.s.current = i
            self.select(nil)
            self.renderer.load(i, sim: self.sim)
            self.renderer.rig.focus(CameraRig.home, distance: CameraRig.homeDistance + 4, yaw: 0)
            self.renderer.rig.snap()
            self.renderer.rig.reset()
            self.publishHUD()
            withAnimation(.easeOut(duration: 0.45)) { self.fade = false }
            if celebrate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.renderer.celebrate()
                    self.showToast("Открыта новая точка: \(Catalog.locations[i].name)!", icon: "building.2.crop.circle.fill",
                                   tint: Pal.accent, big: true)
                }
            }
        }
    }

    // MARK: Empire

    func buyGlobal(_ u: GlobalUpgrade) {
        let l = sim.s.level(u)
        guard l < u.maxLevel else { return }
        let cost = u.cost(l)
        guard sim.s.money >= cost else { return fail("Не хватает денег: нужно \(Fmt.money(cost))") }
        sim.s.money -= cost
        sim.s.global[u] = l + 1
        Sound.shared.play(.upgrade, volume: 0.8)
        Haptics.success()
        renderer.refreshMenu(sim)
        publishHUD()
        tick &+= 1
    }

    func franchise() {
        let gain = sim.s.potentialStars
        guard gain > 0 else { return }
        var fresh = GameState.fresh(stars: sim.s.stars + gain, lifetime: sim.s.lifetimeEarned, franchises: sim.s.franchises + 1)
        fresh.tutorial = 100
        fresh.musicOn = sim.s.musicOn
        fresh.dayTime = sim.s.dayTime
        sim.reset(fresh)
        fillQuests()
        sheet = nil
        select(nil)
        withAnimation(.easeIn(duration: 0.25)) { fade = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.renderer.load(0, sim: self.sim)
            withAnimation(.easeOut(duration: 0.5)) { self.fade = false }
            self.renderer.celebrate()
            Sound.shared.play(.goal)
            Haptics.success()
            self.showToast("Франшиза продана! +\(gain) ★ — все цены навсегда выше", icon: "star.fill", tint: Pal.accent, big: true)
            self.publishHUD()
            self.save()
        }
    }

    func activateBoost() {
        guard sim.s.boostTime <= 0 && sim.s.boostCooldown <= 0 else {
            if sim.s.boostTime <= 0 { fail("Ажиотаж будет доступен через \(Fmt.duration(sim.s.boostCooldown))") }
            return
        }
        sim.s.boostTime = 60
        sim.s.boostCooldown = 240
        Sound.shared.play(.boost, volume: 0.85)
        Haptics.success()
        renderer.celebrate()
        renderer.refreshMenu(sim)
        showToast("Ажиотаж! Все цены ×2 на 60 секунд", icon: "bolt.fill", tint: Pal.accent, big: true)
        publishHUD()
    }

    // MARK: Quests

    private func fillQuests() {
        while sim.s.quests.count < 3 { sim.s.quests.append(makeQuest()) }
    }

    private func makeQuest() -> Quest {
        let st = sim.s
        let n = st.questsDone
        var kinds: [QuestKind] = [.serve, .earn, .upgrade, .tap]
        if st.tutorial >= 90 { kinds.append(.delivery) }
        let best = st.locations.filter { $0.unlocked }.map { $0.rating }.max() ?? 4
        if best < 4.7 { kinds.append(.rating) }
        let active = Set(st.quests.map { $0.kind })
        let pool = kinds.filter { !active.contains($0) }
        let kind = (pool.isEmpty ? kinds : pool).randomElement() ?? .serve
        let ipm = max(sim.incomePerMinute, 40 * Catalog.locations[st.current].tier)
        var target: Double
        var reward: Double
        switch kind {
        case .serve:
            target = Double(15 + n * 4)
            reward = ipm * 1.6
        case .earn:
            target = GameController.nice(ipm * Double.random(in: 3...5))
            reward = target * 0.35
        case .upgrade:
            target = Double(5 + n * 2)
            reward = ipm * 2
        case .tap:
            target = Double(40 + n * 6)
            reward = ipm * 1.3
        case .delivery:
            target = Double(1 + n / 8)
            reward = ipm * 3
        case .rating:
            target = min(5, ((best + 0.25) * 10).rounded() / 10)
            reward = ipm * 2.5
        }
        let q = Quest(id: sim.s.nextQuestId, kind: kind, target: target, progress: kind == .rating ? best : 0,
                      reward: GameController.nice(max(reward, 40)))
        sim.s.nextQuestId += 1
        return q
    }

    static func nice(_ v: Double) -> Double {
        guard v > 10 else { return v.rounded() }
        let p = pow(10, floor(log10(v)) - 1)
        return (v / p).rounded() * p
    }

    private func progressQuests(_ kind: QuestKind, _ amount: Double) {
        for i in sim.s.quests.indices where sim.s.quests[i].kind == kind && !sim.s.quests[i].done {
            sim.s.quests[i].progress += amount
            if sim.s.quests[i].done { questCompleted(sim.s.quests[i]) }
        }
    }

    private func questCompleted(_ q: Quest) {
        guard !showTitle else { return }
        Sound.shared.play(.goal, volume: 0.6)
        Haptics.success()
        showToast("Задание выполнено! Заберите \(Fmt.money(q.reward))", icon: "checkmark.circle.fill", tint: Pal.good)
    }

    func claimQuest(_ id: Int) {
        guard let i = sim.s.quests.firstIndex(where: { $0.id == id }), sim.s.quests[i].done else { return }
        let q = sim.s.quests[i]
        sim.s.money += q.reward
        sim.s.totalEarned += q.reward
        sim.s.lifetimeEarned += q.reward
        sim.s.questsDone += 1
        sim.s.quests.remove(at: i)
        sim.s.quests.insert(makeQuest(), at: i)
        Sound.shared.play(.cash, volume: 0.9)
        Haptics.success()
        renderer.floatText(Fmt.gain(q.reward), at: SIMD3(0, 3.2, 1.5), color: 0xA5D6A7, big: true)
        publishHUD()
        tick &+= 1
    }

    // MARK: Tutorial

    static let tutorialTexts: [String] = [
        "Добро пожаловать в «Шаурма Империю»! Это ваш первый ларёк у метро: повар крутит шаурму, кассир продаёт, гости платят.",
        "Нажимайте на вертел — повар будет готовить быстрее.",
        "Копите деньги и откройте автомат с колой. Нажмите на жёлтую табличку.",
        "Нажмите на вертел, чтобы открыть его карточку.",
        "Нажмите «Улучшить»: шаурма подорожает и будет готовиться быстрее.",
        "Теперь нажмите на прилавок с кассой.",
        "Улучшите кассира — гости будут платить быстрее и оставлять чаевые.",
        "Отлично! Выполняйте задания, открывайте новые точки на карте города, принимайте курьеров и встречайте критиков. Удачи, магнат!",
    ]

    var tutorialActive: Bool { sim.s.tutorial < GameController.tutorialTexts.count }

    private func tutorialTarget(_ step: Int) -> SIMD3<Float>? {
        switch step {
        case 1, 3: return SIMD3(Layout.stationX[0] + StationFactory.appX, 2.5, Layout.stationZ)
        case 2: return L.stations[1].level == 0 ? SIMD3(Layout.stationX[1], 3.1, Layout.stationZ) : nil
        case 5: return SIMD3(0.8, 1.9, 1.2)
        default: return nil
        }
    }

    private func updateTutorial() {
        var step = sim.s.tutorial
        guard step < GameController.tutorialTexts.count else {
            renderer.setHint(nil)
            return
        }
        while true {
            let done: Bool
            switch step {
            case 1: done = tutorialTaps >= 6 || L.stations[1].level > 0
            case 2: done = L.stations[1].level > 0
            case 3: done = selected == .station(0) || L.stations[0].level >= 2
            case 4: done = L.stations[0].level >= 2
            case 5: done = selected == .counter || L.cashier >= 2
            case 6: done = L.cashier >= 2
            default: done = false
            }
            if done { step += 1 } else { break }
        }
        if step != sim.s.tutorial {
            sim.s.tutorial = step
            Sound.shared.play(.pop, volume: 0.5)
        }
        renderer.setHint(showTitle || loc != 0 ? nil : tutorialTarget(step))
    }

    func advanceTutorial() {
        if sim.s.tutorial >= GameController.tutorialTexts.count - 1 {
            sim.s.tutorial = 100
            renderer.celebrate()
            Sound.shared.play(.goal, volume: 0.7)
        } else {
            sim.s.tutorial += 1
            Sound.shared.play(.tap)
        }
        publishHUD()
    }

    func skipTutorial() {
        sim.s.tutorial = 100
        renderer.setHint(nil)
        publishHUD()
    }

    // MARK: Persistence

    func newGame() {
        var fresh = GameState.fresh()
        fresh.tutorial = 100
        sim.reset(fresh)
        fillQuests()
        sim.warmUp(seconds: 15)
        select(nil)
        renderer.load(0, sim: sim)
        hasSave = true
        publishHUD()
        save()
    }

    private static var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("shawarma_empire.json")
    }

    func save() {
        guard scenario == nil else { return }
        sim.s.lastActive = Date().timeIntervalSince1970
        guard let data = try? JSONEncoder().encode(sim.s) else { return }
        DispatchQueue.global(qos: .utility).async {
            try? data.write(to: GameController.saveURL, options: .atomic)
        }
    }

    private static func load() -> GameState? {
        guard let data = try? Data(contentsOf: saveURL),
              let s = try? JSONDecoder().decode(GameState.self, from: data),
              s.isValid else { return nil }
        return s
    }

    // MARK: QA scenarios (launch argument -scenario <name>)

    /// A developed empire with the given location open and upgraded.
    static func developed(upTo last: Int, current: Int, decor: Int = 7) -> GameState {
        var s = GameState.fresh()
        s.tutorial = 100
        s.money = Catalog.locations[last].tier * 40_000
        s.stars = 3
        for i in 0...last {
            s.locations[i].unlocked = true
            for j in 0..<4 {
                let lv = [42, 30, 26, 12][j] - i * 2
                s.locations[i].stations[j] = StationState(level: max(1, lv), cooks: j < 2 ? 2 : 1, stock: 3, progress: 0.3)
            }
            s.locations[i].windows = i == last ? 2 : 3
            s.locations[i].cashier = 9
            s.locations[i].marketing = 6
            s.locations[i].decor = decor
            s.locations[i].rating = 4.6
        }
        s.current = current
        s.global = [.ads: 3, .sauce: 2, .night: 1, .courier: 1]
        s.questsDone = 6
        return s
    }

    static func scenarioState(_ sc: String) -> GameState {
        switch sc {
        case "title", "tutorial", "autoplay":
            var s = GameState.fresh()
            if sc == "tutorial" {
                s.tutorial = 1
                s.money = 45
            }
            return s
        case "loc1": return developed(upTo: 1, current: 1, decor: 6)
        case "loc2": return developed(upTo: 2, current: 2, decor: 8)
        case "loc3": return developed(upTo: 3, current: 3, decor: 9)
        case "loc4", "rich": return developed(upTo: 4, current: 4, decor: 10)
        case "night":
            var s = developed(upTo: 0, current: 0, decor: 10)
            s.dayTime = 0.86
            return s
        case "dusk":
            var s = developed(upTo: 1, current: 1, decor: 10)
            s.dayTime = 0.745
            return s
        case "early":
            var s = GameState.fresh()
            s.tutorial = 100
            s.money = 420
            s.locations[0].stations[1] = StationState(level: 3, cooks: 1, stock: 2, progress: 0)
            s.locations[0].stations[0].level = 6
            return s
        default:
            return developed(upTo: 0, current: 0, decor: 5)
        }
    }

    private func applyScenario(_ sc: String) {
        let rig = renderer.rig
        switch sc {
        case "title":
            break
        case "tutorial":
            break
        case "station":
            select(.station(0))
            rig.focus(SIMD3(-2.5, 0, 0), distance: 11)
        case "locked":
            sim.s.locations[0].stations[3] = StationState()
            renderer.refreshStructure(sim, animated: false)
            select(.locked(3))
        case "counter":
            select(.counter)
        case "upgrades":
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.sheet = .upgrades }
        case "city":
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.sheet = .city }
        case "empire":
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.sheet = .empire }
        case "quests":
            sim.s.quests[0].progress = sim.s.quests[0].target
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.sheet = .quests }
        case "menu":
            sim.s.history = (0..<30).map { Double($0 * $0) * 3 + 200 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.sheet = .menu }
        case "closeup":
            rig.focus(SIMD3(-1, 0, 1.2), distance: 8, yaw: 0.45)
        case "rain":
            sim.rainTime = 999
            rig.focus(SIMD3(0, 0, 2.5), distance: 14, yaw: -0.25)
        case "delivery":
            sim.runtimes[loc].deliveryCooldown = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in self?.select(.courier) }
        case "street":
            rig.focus(SIMD3(2, 0, 5), distance: 12, yaw: 0.6)
        case "stats":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.view?.showsStatistics = true }
        case "autoplay":
            runAutoplay()
        case "gift":
            renderer.spawnGift(at: -7, dir: 1)
        case "daily":
            sim.s.bonusDay = GameController.today - 1
            sim.s.bonusStreak = 3
            checkDaily(after: 1.0)
        default:
            break
        }
        rig.snap()
        publishHUD()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            let rt = self.sim.runtimes[self.loc]
            qaLog("scenario=\(sc) money=\(Int(self.sim.s.money)) customers=\(rt.customers.count) icons=\(self.icons.count) ipm=\(Int(self.sim.incomePerMinute)) gift=\(self.renderer.hasGift)")
            qaLog("bake \(Bake.stats.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))")
        }
    }

    /// Drives the real input path (screen taps) through the tutorial.
    private func runAutoplay() {
        func at(_ t: Double, _ f: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: f)
        }
        func tapWorld(_ p: SIMD3<Float>) {
            guard let sp = renderer.screenPoint(p) else {
                qaLog("point \(p) not on screen")
                return
            }
            handleTap(sp)
        }
        let spit = SIMD3<Float>(Layout.stationX[0], 1.0, Layout.stationZ + 0.2)
        at(1.0) { self.advanceTutorial() }
        for k in 0..<8 { at(1.4 + Double(k) * 0.15) { tapWorld(spit) } }
        at(3.0) { self.sim.s.money += 200 }
        at(3.3) { tapWorld(SIMD3(Layout.stationX[1], 1.0, Layout.stationZ + 0.2)) }
        at(3.7) { if case .locked(let j) = self.selected { self.unlockStation(j) } }
        at(4.4) { tapWorld(spit) }
        at(4.8) { if case .station(let j) = self.selected { self.upgradeStation(j) } }
        at(5.4) { tapWorld(SIMD3(0.8, 1.0, 1.2)) }
        at(5.8) { if self.selected == .counter { self.upgradeCashier() } }
        at(7.0) {
            let s = self.sim.s
            let report = "tut=\(s.tutorial) sel=\(String(describing: self.selected)) st0=\(s.locations[0].stations[0].level) " +
                "st1=\(s.locations[0].stations[1].level) cashier=\(s.locations[0].cashier) taps=\(self.tutorialTaps) money=\(Int(s.money))"
            qaLog("AUTOPLAY " + report)
        }
    }
}

func qaLog(_ s: String) {
    FileHandle.standardError.write(("[QA] " + s + "\n").data(using: .utf8)!)
}
