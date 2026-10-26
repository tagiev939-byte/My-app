import Foundation

struct StationState: Codable, Equatable {
    var level = 0
    var cooks = 0
    var stock = 0
    var progress = 0.0
}

struct LocationState: Codable, Equatable {
    var unlocked = false
    var stations = Array(repeating: StationState(), count: 4)
    var windows = 1
    var cashier = 1
    var marketing = 0
    var decor = 0
    var rating = 4.2
    var served = 0
    var earned = 0.0
}

struct Quest: Codable, Identifiable, Equatable {
    var id: Int
    var kind: QuestKind
    var target: Double
    var progress: Double
    var reward: Double

    var done: Bool { progress >= target }
    var fraction: Double { min(1, progress / max(target, 0.0001)) }
}

struct GameState: Codable {
    var version = 1
    var money: Double = 30
    var totalEarned = 0.0
    var lifetimeEarned = 0.0
    var stars = 0
    var current = 0
    var locations: [LocationState] = Array(repeating: LocationState(), count: Catalog.locations.count)
    var global: [GlobalUpgrade: Int] = [:]
    var quests: [Quest] = []
    var questsDone = 0
    var nextQuestId = 1
    var tutorial = 0
    var dayTime = 0.16
    var playTime = 0.0
    var boostTime = 0.0
    var boostCooldown = 0.0
    var incomeRate = 0.0
    var history: [Double] = []
    var lastActive = Date().timeIntervalSince1970
    var served = 0
    var angry = 0
    var deliveries = 0
    var franchises = 0
    var musicOn = true

    static func fresh(stars: Int = 0, lifetime: Double = 0, franchises: Int = 0) -> GameState {
        var s = GameState()
        s.stars = stars
        s.lifetimeEarned = lifetime
        s.franchises = franchises
        s.locations[0].unlocked = true
        s.locations[0].stations[0] = StationState(level: 1, cooks: 1, stock: 2, progress: 0)
        return s
    }

    var isValid: Bool { version == 1 && locations.count == Catalog.locations.count }

    func level(_ u: GlobalUpgrade) -> Int { global[u] ?? 0 }

    /// Price multiplier from sauce, franchise stars and the x2 rush boost.
    var priceMult: Double {
        (1 + 0.1 * Double(level(.sauce))) * (1 + 0.1 * Double(stars)) * (boostTime > 0 ? 2 : 1)
    }

    var offlineHours: Double { 2 + Double(level(.night)) }
    var unlockedCount: Int { locations.filter { $0.unlocked }.count }
    var potentialStars: Int { max(0, Rules.franchiseStars(lifetime: lifetimeEarned) - stars) }
}
