import Foundation
import UIKit
import SwiftUI

// MARK: - Colors

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - Grid

struct TilePos: Hashable, Codable {
    var x: Int
    var y: Int

    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    func moved(_ d: Dir) -> TilePos { TilePos(x + d.dx, y + d.dy) }
}

/// Grid direction. `up` is north (-Z in the 3D world).
enum Dir: Int, Codable, CaseIterable {
    case up = 0, right, down, left

    var dx: Int {
        switch self {
        case .right: return 1
        case .left: return -1
        default: return 0
        }
    }

    var dy: Int {
        switch self {
        case .up: return -1
        case .down: return 1
        default: return 0
        }
    }

    var cw: Dir { Dir(rawValue: (rawValue + 1) % 4)! }
    var ccw: Dir { Dir(rawValue: (rawValue + 3) % 4)! }
    var opposite: Dir { Dir(rawValue: (rawValue + 2) % 4)! }

    /// Rotation around Y that turns a model facing -Z into this direction.
    var yaw: Float { -Float(rawValue) * Float.pi / 2 }
}

// MARK: - Resources

enum Resource: Int, Codable, CaseIterable {
    case none = 0, iron, copper, stone, coal, gold, quartz

    var ore: ItemType? {
        switch self {
        case .none: return nil
        case .iron: return .ironOre
        case .copper: return .copperOre
        case .stone: return .stone
        case .coal: return .coal
        case .gold: return .goldOre
        case .quartz: return .quartz
        }
    }

    var title: String {
        switch self {
        case .none: return "Пусто"
        case .iron: return "Железо"
        case .copper: return "Медь"
        case .stone: return "Камень"
        case .coal: return "Уголь"
        case .gold: return "Золото"
        case .quartz: return "Кварц"
        }
    }

    /// Color of the rocks in the world.
    var rockHex: UInt32 {
        switch self {
        case .none: return 0x888888
        case .iron: return 0x8E9FB3
        case .copper: return 0xD9783F
        case .stone: return 0xC9BBA3
        case .coal: return 0x2E2F36
        case .gold: return 0xF2C230
        case .quartz: return 0xF3D9F2
        }
    }

    /// Tint painted into the ground texture under a deposit.
    var groundHex: UInt32 {
        switch self {
        case .none: return 0x7CB65A
        case .iron: return 0x7D8A80
        case .copper: return 0x9C7A4E
        case .stone: return 0xA59B7C
        case .coal: return 0x4E5345
        case .gold: return 0xA59A4A
        case .quartz: return 0x9C9A9E
        }
    }
}

// MARK: - Items

enum ItemType: String, Codable, CaseIterable {
    case ironOre, copperOre, stone, coal, goldOre, quartz
    case ironPlate, copperPlate, brick, glass, goldBar, steel
    case gear, wire, circuit, frame, motor, processor, robot

    var title: String {
        switch self {
        case .ironOre: return "Железная руда"
        case .copperOre: return "Медная руда"
        case .stone: return "Камень"
        case .coal: return "Уголь"
        case .goldOre: return "Золотая руда"
        case .quartz: return "Кварц"
        case .ironPlate: return "Железная пластина"
        case .copperPlate: return "Медная пластина"
        case .brick: return "Кирпич"
        case .glass: return "Стекло"
        case .goldBar: return "Золотой слиток"
        case .steel: return "Сталь"
        case .gear: return "Шестерня"
        case .wire: return "Провод"
        case .circuit: return "Микросхема"
        case .frame: return "Каркас"
        case .motor: return "Мотор"
        case .processor: return "Процессор"
        case .robot: return "Робот"
        }
    }

    var value: Double {
        switch self {
        case .ironOre, .copperOre, .stone: return 2
        case .coal: return 3
        case .quartz: return 4
        case .goldOre: return 6
        case .ironPlate, .copperPlate: return 7
        case .brick: return 11
        case .glass: return 20
        case .goldBar: return 35
        case .steel: return 40
        case .gear: return 24
        case .wire: return 5
        case .circuit: return 55
        case .frame: return 150
        case .motor: return 280
        case .processor: return 380
        case .robot: return 1800
        }
    }

    var hex: UInt32 {
        switch self {
        case .ironOre: return 0x8E9FB3
        case .copperOre: return 0xD9783F
        case .stone: return 0xC9BBA3
        case .coal: return 0x2E2F36
        case .goldOre: return 0xE8B92E
        case .quartz: return 0xF3D9F2
        case .ironPlate: return 0xC9D3DD
        case .copperPlate: return 0xE8935A
        case .brick: return 0xB5533C
        case .glass: return 0x9FE3F0
        case .goldBar: return 0xF7C948
        case .steel: return 0x6F7E91
        case .gear: return 0xE3B341
        case .wire: return 0xE58A3A
        case .circuit: return 0x2FA866
        case .frame: return 0x9B6BE0
        case .motor: return 0x3D85E0
        case .processor: return 0x30343C
        case .robot: return 0xF0F3F7
        }
    }

    var color: Color { Color(hex: hex) }
    var iconKey: String { "item." + rawValue }
}

// MARK: - Recipes

struct Ingredient: Hashable {
    let item: ItemType
    let count: Int
}

struct Recipe: Identifiable {
    let id: String
    let machine: BuildingType
    let inputs: [Ingredient]
    let output: ItemType
    let outputCount: Int
    let time: Double

    func need(_ item: ItemType) -> Int? {
        inputs.first(where: { $0.item == item })?.count
    }

    static let all: [Recipe] = [
        Recipe(id: "ironPlate", machine: .smelter, inputs: [Ingredient(item: .ironOre, count: 1)],
               output: .ironPlate, outputCount: 1, time: 1.0),
        Recipe(id: "copperPlate", machine: .smelter, inputs: [Ingredient(item: .copperOre, count: 1)],
               output: .copperPlate, outputCount: 1, time: 1.0),
        Recipe(id: "brick", machine: .smelter, inputs: [Ingredient(item: .stone, count: 2)],
               output: .brick, outputCount: 1, time: 1.5),
        Recipe(id: "glass", machine: .smelter, inputs: [Ingredient(item: .quartz, count: 2)],
               output: .glass, outputCount: 1, time: 1.5),
        Recipe(id: "goldBar", machine: .smelter, inputs: [Ingredient(item: .goldOre, count: 2)],
               output: .goldBar, outputCount: 1, time: 2.0),
        Recipe(id: "steel", machine: .smelter,
               inputs: [Ingredient(item: .ironPlate, count: 2), Ingredient(item: .coal, count: 1)],
               output: .steel, outputCount: 1, time: 2.5),

        Recipe(id: "gear", machine: .assembler, inputs: [Ingredient(item: .ironPlate, count: 2)],
               output: .gear, outputCount: 1, time: 1.5),
        Recipe(id: "wire", machine: .assembler, inputs: [Ingredient(item: .copperPlate, count: 1)],
               output: .wire, outputCount: 2, time: 1.0),
        Recipe(id: "circuit", machine: .assembler,
               inputs: [Ingredient(item: .ironPlate, count: 1), Ingredient(item: .wire, count: 3)],
               output: .circuit, outputCount: 1, time: 2.5),
        Recipe(id: "frame", machine: .assembler,
               inputs: [Ingredient(item: .brick, count: 4), Ingredient(item: .steel, count: 1)],
               output: .frame, outputCount: 1, time: 4.0),
        Recipe(id: "motor", machine: .assembler,
               inputs: [Ingredient(item: .gear, count: 2), Ingredient(item: .circuit, count: 1),
                        Ingredient(item: .steel, count: 1)],
               output: .motor, outputCount: 1, time: 5.0),
        Recipe(id: "processor", machine: .assembler,
               inputs: [Ingredient(item: .circuit, count: 2), Ingredient(item: .goldBar, count: 1),
                        Ingredient(item: .glass, count: 1)],
               output: .processor, outputCount: 1, time: 6.0),
        Recipe(id: "robot", machine: .assembler,
               inputs: [Ingredient(item: .motor, count: 1), Ingredient(item: .processor, count: 1),
                        Ingredient(item: .frame, count: 1)],
               output: .robot, outputCount: 1, time: 10.0),
    ]

    static func byId(_ id: String) -> Recipe? { all.first(where: { $0.id == id }) }
    static func list(for machine: BuildingType) -> [Recipe] { all.filter { $0.machine == machine } }
}

// MARK: - Buildings

enum BuildingType: String, Codable, CaseIterable {
    case conveyor, drill, smelter, assembler, splitter, junction, market

    var title: String {
        switch self {
        case .conveyor: return "Конвейер"
        case .drill: return "Бур"
        case .smelter: return "Печь"
        case .assembler: return "Сборщик"
        case .splitter: return "Сплиттер"
        case .junction: return "Перекрёсток"
        case .market: return "Рынок"
        }
    }

    var info: String {
        switch self {
        case .conveyor: return "Проведите пальцем по карте, чтобы проложить линию. Двумя пальцами — двигать камеру."
        case .drill: return "Ставится на залежь руды. Выдаёт руду по стрелке."
        case .smelter: return "Плавит руду в пластины, кирпич, стекло, слитки и сталь."
        case .assembler: return "Собирает детали: шестерни, провода, микросхемы, моторы, роботов."
        case .splitter: return "Делит поток по очереди: влево, вперёд и вправо."
        case .junction: return "Пропускает два потока крест-накрест, не смешивая их."
        case .market: return "Продаёт всё, что в него попадает, с любой стороны."
        }
    }

    var cost: Double {
        switch self {
        case .conveyor: return 2
        case .drill: return 40
        case .smelter: return 90
        case .assembler: return 180
        case .splitter: return 30
        case .junction: return 25
        case .market: return 60
        }
    }

    var hasDirection: Bool { self != .market && self != .junction }
    var isMachine: Bool { self == .smelter || self == .assembler }
    var isUpgradable: Bool { self == .drill || self == .smelter || self == .assembler || self == .market }
    var iconKey: String { "building." + rawValue }

    /// Goal index that must be completed to unlock this building.
    var unlockGoal: Int? {
        switch self {
        case .splitter: return 3
        case .assembler: return 4
        case .junction: return 5
        default: return nil
        }
    }

    static let maxLevel = 10

    func upgradeCost(level: Int) -> Double {
        (cost * 1.5 * pow(1.62, Double(level - 1))).rounded()
    }
}

/// Speed multiplier from a building's level.
func levelMultiplier(_ level: Int) -> Double { 1 + 0.3 * Double(level - 1) }
/// Price multiplier from a market's level.
func marketMultiplier(_ level: Int) -> Double { 1 + 0.1 * Double(level - 1) }

// MARK: - Global upgrades

enum UpgradeType: String, Codable, CaseIterable {
    case belts, prices, automation, offline

    var title: String {
        switch self {
        case .belts: return "Быстрые конвейеры"
        case .prices: return "Торговые связи"
        case .automation: return "Автоматизация"
        case .offline: return "Ночная смена"
        }
    }

    var info: String {
        switch self {
        case .belts: return "+20% к скорости всех конвейеров"
        case .prices: return "+10% к цене всех продаж"
        case .automation: return "+15% к скорости буров и станков"
        case .offline: return "+1 час дохода, пока игра закрыта"
        }
    }

    var icon: String {
        switch self {
        case .belts: return "forward.fill"
        case .prices: return "chart.line.uptrend.xyaxis"
        case .automation: return "gearshape.2.fill"
        case .offline: return "moon.stars.fill"
        }
    }

    var maxLevel: Int {
        switch self {
        case .belts: return 5
        case .prices: return 10
        case .automation: return 6
        case .offline: return 4
        }
    }

    func cost(level: Int) -> Double {
        switch self {
        case .belts: return (800 * pow(2.2, Double(level))).rounded()
        case .prices: return (1500 * pow(2.0, Double(level))).rounded()
        case .automation: return (2000 * pow(2.3, Double(level))).rounded()
        case .offline: return (1000 * pow(2.6, Double(level))).rounded()
        }
    }
}

// MARK: - Goals

enum GoalKind {
    case build(BuildingType)
    case produce(ItemType)
    case earn
    case level
    case land
}

struct Goal {
    let title: String
    let detail: String
    let kind: GoalKind
    let target: Double
    let reward: Double

    var iconKey: String? {
        switch kind {
        case .build(let t): return t.iconKey
        case .produce(let i): return i.iconKey
        default: return nil
        }
    }

    var symbol: String {
        switch kind {
        case .earn: return "dollarsign"
        case .level: return "arrow.up.circle.fill"
        case .land: return "map.fill"
        default: return "flag.fill"
        }
    }

    static let all: [Goal] = [
        Goal(title: "Больше буров", detail: "Поставьте ещё два бура на железную руду рядом с конвейером",
             kind: .build(.drill), target: 3, reward: 120),
        Goal(title: "Модернизация", detail: "Откройте карточку бура в режиме «Осмотр» и улучшите его",
             kind: .level, target: 2, reward: 150),
        Goal(title: "Переплавка", detail: "Поставьте печь на пути руды к рынку. Пластина дороже руды в 3,5 раза",
             kind: .produce(.ironPlate), target: 20, reward: 250),
        Goal(title: "Медь", detail: "Добудьте медную руду и переплавьте её в пластины",
             kind: .produce(.copperPlate), target: 25, reward: 400),
        Goal(title: "Первые $3 000", detail: "Заработайте на продажах $3 000",
             kind: .earn, target: 3_000, reward: 500),
        Goal(title: "Шестерни", detail: "Соберите шестерни из железных пластин в сборщике",
             kind: .produce(.gear), target: 30, reward: 800),
        Goal(title: "Новые земли", detail: "Купите соседний участок — нажмите на табличку с ценой",
             kind: .land, target: 2, reward: 1_000),
        Goal(title: "Провода", detail: "Сделайте провода из медных пластин",
             kind: .produce(.wire), target: 60, reward: 1_200),
        Goal(title: "Микросхемы", detail: "Микросхема = железная пластина + 3 провода",
             kind: .produce(.circuit), target: 25, reward: 2_500),
        Goal(title: "Мастер-класс", detail: "Улучшите любое здание до 5 уровня",
             kind: .level, target: 5, reward: 3_000),
        Goal(title: "Сталь", detail: "Сталь = 2 железные пластины + уголь, плавится в печи",
             kind: .produce(.steel), target: 30, reward: 4_000),
        Goal(title: "Каркасы", detail: "Каркас = 4 кирпича + сталь",
             kind: .produce(.frame), target: 15, reward: 6_000),
        Goal(title: "Моторы", detail: "Мотор = 2 шестерни + микросхема + сталь",
             kind: .produce(.motor), target: 15, reward: 9_000),
        Goal(title: "Золотая лихорадка", detail: "Найдите золото на новых участках и выплавьте слитки",
             kind: .produce(.goldBar), target: 20, reward: 12_000),
        Goal(title: "Процессоры", detail: "Процессор = 2 микросхемы + золотой слиток + стекло",
             kind: .produce(.processor), target: 10, reward: 20_000),
        Goal(title: "Роботы", detail: "Робот = мотор + процессор + каркас",
             kind: .produce(.robot), target: 10, reward: 50_000),
        Goal(title: "Империя", detail: "Заработайте на продажах $1 000 000",
             kind: .earn, target: 1_000_000, reward: 250_000),
    ]
}

// MARK: - Contracts

struct Contract: Codable, Equatable {
    var item: ItemType
    var amount: Int
    var delivered: Int
    var reward: Double
    var timeLeft: Double
    var total: Double
}

// MARK: - Tools

enum Tool: Equatable {
    case inspect
    case build(BuildingType)
    case demolish
}

// MARK: - Formatting

enum Fmt {
    private static let grouping: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f
    }()

    static func money(_ v: Double) -> String {
        let a = abs(v)
        let sign = v < 0 ? "-" : ""
        if a >= 1e12 { return sign + String(format: "$%.2fT", a / 1e12) }
        if a >= 1e9 { return sign + String(format: "$%.2fB", a / 1e9) }
        if a >= 1e6 { return sign + String(format: "$%.2fM", a / 1e6) }
        if a >= 1e5 { return sign + String(format: "$%.1fK", a / 1e3) }
        return sign + "$" + (grouping.string(from: NSNumber(value: a.rounded(.down))) ?? "\(Int(a))")
    }

    static func gain(_ v: Double) -> String {
        if v < 10 { return String(format: "+$%.1f", v) }
        return "+" + money(v)
    }

    static func duration(_ s: Double) -> String {
        let t = max(0, Int(s))
        let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        if h > 0 { return "\(h) ч \(m) мин" }
        if m > 0 { return String(format: "%d:%02d", m, sec) }
        return "\(sec) с"
    }
}
