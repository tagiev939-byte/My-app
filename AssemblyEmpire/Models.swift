import SwiftUI

// MARK: - Basic geometry

struct TilePos: Hashable, Codable {
    var x: Int
    var y: Int

    func moved(_ d: Dir) -> TilePos { TilePos(x: x + d.dx, y: y + d.dy) }
}

enum Dir: Int, Codable, CaseIterable {
    case up = 0, right = 1, down = 2, left = 3

    var dx: Int {
        switch self {
        case .left: return -1
        case .right: return 1
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
    var radians: Double { Double(rawValue) * Double.pi / 2 }
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

// MARK: - Resources & items

enum Resource: Int, Codable {
    case none = 0, iron, copper, stone, coal

    var ore: ItemType? {
        switch self {
        case .none: return nil
        case .iron: return .ironOre
        case .copper: return .copperOre
        case .stone: return .stone
        case .coal: return .coal
        }
    }

    var color: Color {
        switch self {
        case .none: return .clear
        case .iron: return Color(hex: 0x8FA6BA)
        case .copper: return Color(hex: 0xE08A4E)
        case .stone: return Color(hex: 0xB9AE9C)
        case .coal: return Color(hex: 0x4A4A55)
        }
    }

    var title: String {
        switch self {
        case .none: return "Пусто"
        case .iron: return "Железо"
        case .copper: return "Медь"
        case .stone: return "Камень"
        case .coal: return "Уголь"
        }
    }
}

enum ItemShape {
    case ore, plate, brick, ingot, gear, coil, chip, motor, frame
}

enum ItemType: String, Codable, CaseIterable {
    case ironOre, copperOre, stone, coal
    case ironPlate, copperPlate, brick, steel
    case gear, wire, circuit, motor, frame

    var title: String {
        switch self {
        case .ironOre: return "Железная руда"
        case .copperOre: return "Медная руда"
        case .stone: return "Камень"
        case .coal: return "Уголь"
        case .ironPlate: return "Железная пластина"
        case .copperPlate: return "Медная пластина"
        case .brick: return "Кирпич"
        case .steel: return "Сталь"
        case .gear: return "Шестерня"
        case .wire: return "Провод"
        case .circuit: return "Микросхема"
        case .motor: return "Мотор"
        case .frame: return "Каркас"
        }
    }

    var value: Double {
        switch self {
        case .ironOre, .copperOre, .stone: return 1
        case .coal: return 2
        case .ironPlate, .copperPlate: return 4
        case .brick: return 5
        case .steel: return 22
        case .gear: return 12
        case .wire: return 3
        case .circuit: return 32
        case .motor: return 150
        case .frame: return 75
        }
    }

    var color: Color {
        switch self {
        case .ironOre: return Color(hex: 0x8FA6BA)
        case .copperOre: return Color(hex: 0xE08A4E)
        case .stone: return Color(hex: 0xB9AE9C)
        case .coal: return Color(hex: 0x34343C)
        case .ironPlate: return Color(hex: 0xD3DEE7)
        case .copperPlate: return Color(hex: 0xF4A56E)
        case .brick: return Color(hex: 0xB9553D)
        case .steel: return Color(hex: 0x8C9DB2)
        case .gear: return Color(hex: 0xE7C45C)
        case .wire: return Color(hex: 0xF2A93B)
        case .circuit: return Color(hex: 0x37B46F)
        case .motor: return Color(hex: 0x4C93EC)
        case .frame: return Color(hex: 0xA77BE0)
        }
    }

    var shape: ItemShape {
        switch self {
        case .ironOre, .copperOre, .stone, .coal: return .ore
        case .ironPlate, .copperPlate: return .plate
        case .brick: return .brick
        case .steel: return .ingot
        case .gear: return .gear
        case .wire: return .coil
        case .circuit: return .chip
        case .motor: return .motor
        case .frame: return .frame
        }
    }
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
        Recipe(id: "ironPlate", machine: .smelter,
               inputs: [Ingredient(item: .ironOre, count: 1)],
               output: .ironPlate, outputCount: 1, time: 1.2),
        Recipe(id: "copperPlate", machine: .smelter,
               inputs: [Ingredient(item: .copperOre, count: 1)],
               output: .copperPlate, outputCount: 1, time: 1.2),
        Recipe(id: "brick", machine: .smelter,
               inputs: [Ingredient(item: .stone, count: 2)],
               output: .brick, outputCount: 1, time: 1.6),
        Recipe(id: "steel", machine: .smelter,
               inputs: [Ingredient(item: .ironPlate, count: 2), Ingredient(item: .coal, count: 1)],
               output: .steel, outputCount: 1, time: 3.0),

        Recipe(id: "gear", machine: .assembler,
               inputs: [Ingredient(item: .ironPlate, count: 2)],
               output: .gear, outputCount: 1, time: 1.5),
        Recipe(id: "wire", machine: .assembler,
               inputs: [Ingredient(item: .copperPlate, count: 1)],
               output: .wire, outputCount: 2, time: 1.0),
        Recipe(id: "circuit", machine: .assembler,
               inputs: [Ingredient(item: .ironPlate, count: 1), Ingredient(item: .wire, count: 3)],
               output: .circuit, outputCount: 1, time: 3.0),
        Recipe(id: "frame", machine: .assembler,
               inputs: [Ingredient(item: .brick, count: 4), Ingredient(item: .steel, count: 1)],
               output: .frame, outputCount: 1, time: 4.0),
        Recipe(id: "motor", machine: .assembler,
               inputs: [Ingredient(item: .gear, count: 2), Ingredient(item: .circuit, count: 1),
                        Ingredient(item: .steel, count: 1)],
               output: .motor, outputCount: 1, time: 5.0),
    ]

    static func byId(_ id: String) -> Recipe? { all.first(where: { $0.id == id }) }
    static func list(for machine: BuildingType) -> [Recipe] { all.filter { $0.machine == machine } }
}

// MARK: - Buildings

enum BuildingType: String, Codable, CaseIterable {
    case belt, miner, smelter, seller, splitter, assembler

    var title: String {
        switch self {
        case .belt: return "Конвейер"
        case .miner: return "Бур"
        case .smelter: return "Печь"
        case .seller: return "Рынок"
        case .splitter: return "Сплиттер"
        case .assembler: return "Сборщик"
        }
    }

    var info: String {
        switch self {
        case .belt: return "Перевозит предметы. Проведите пальцем, чтобы проложить линию."
        case .miner: return "Ставится на залежь и добывает руду. Выдаёт её вперёд по стрелке."
        case .smelter: return "Плавит руду в пластины, кирпичи и сталь."
        case .seller: return "Продаёт всё, что в него попадает."
        case .splitter: return "Делит поток по очереди: влево, вперёд, вправо."
        case .assembler: return "Собирает сложные детали: шестерни, провода, микросхемы, моторы."
        }
    }

    var cost: Double {
        switch self {
        case .belt: return 3
        case .miner: return 40
        case .smelter: return 75
        case .seller: return 50
        case .splitter: return 25
        case .assembler: return 150
        }
    }

    var hasDirection: Bool { self != .seller }
    var isMachine: Bool { self == .smelter || self == .assembler }

    /// Index of the goal that must be completed to unlock this building (nil = available from start).
    var unlockGoal: Int? {
        switch self {
        case .splitter: return 1
        case .assembler: return 2
        default: return nil
        }
    }
}

// MARK: - Upgrades

enum UpgradeType: String, Codable, CaseIterable {
    case miners, belts, machines, prices

    var title: String {
        switch self {
        case .miners: return "Мощные буры"
        case .belts: return "Быстрые конвейеры"
        case .machines: return "Автоматизация"
        case .prices: return "Торговые связи"
        }
    }

    var info: String {
        switch self {
        case .miners: return "+25% к скорости добычи"
        case .belts: return "+25% к скорости конвейеров"
        case .machines: return "+25% к скорости печей и сборщиков"
        case .prices: return "+15% к цене продажи"
        }
    }

    var icon: String {
        switch self {
        case .miners: return "hammer.fill"
        case .belts: return "forward.fill"
        case .machines: return "gearshape.2.fill"
        case .prices: return "chart.line.uptrend.xyaxis"
        }
    }

    var maxLevel: Int { self == .prices ? 10 : 6 }

    var baseCost: Double {
        switch self {
        case .miners: return 300
        case .belts: return 250
        case .machines: return 600
        case .prices: return 800
        }
    }

    func cost(level: Int) -> Double { (baseCost * pow(1.85, Double(level))).rounded() }
}

// MARK: - Goals

enum GoalKind {
    case sell(ItemType)
    case produce(ItemType)
    case earn
}

struct Goal {
    let title: String
    let detail: String
    let kind: GoalKind
    let target: Double
    let reward: Double

    func current(_ world: World) -> Double {
        switch kind {
        case .sell(let item): return Double(world.sold[item] ?? 0)
        case .produce(let item): return Double(world.produced[item] ?? 0)
        case .earn: return world.totalEarned
        }
    }

    var icon: ItemType? {
        switch kind {
        case .sell(let i), .produce(let i): return i
        case .earn: return nil
        }
    }

    static let all: [Goal] = [
        Goal(title: "Первая руда",
             detail: "Поставьте бур на железо, проложите конвейер к рынку и продайте 10 руды",
             kind: .sell(.ironOre), target: 10, reward: 150),
        Goal(title: "Плавка",
             detail: "Направьте руду в печь и выплавьте 15 железных пластин",
             kind: .produce(.ironPlate), target: 15, reward: 250),
        Goal(title: "Первая тысяча",
             detail: "Заработайте на продажах $1 000",
             kind: .earn, target: 1_000, reward: 300),
        Goal(title: "Шестерёнки",
             detail: "Соберите 25 шестерней в сборщике",
             kind: .produce(.gear), target: 25, reward: 600),
        Goal(title: "Электроника",
             detail: "Сделайте провод из меди и соберите 15 микросхем",
             kind: .produce(.circuit), target: 15, reward: 1_500),
        Goal(title: "Сталь",
             detail: "Выплавьте 20 стали из пластин и угля",
             kind: .produce(.steel), target: 20, reward: 2_000),
        Goal(title: "Стройка",
             detail: "Соберите 10 каркасов из кирпича и стали",
             kind: .produce(.frame), target: 10, reward: 4_000),
        Goal(title: "Моторы",
             detail: "Соберите 10 моторов",
             kind: .produce(.motor), target: 10, reward: 6_000),
        Goal(title: "Империя",
             detail: "Заработайте всего $100 000",
             kind: .earn, target: 100_000, reward: 25_000),
    ]
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
        if a >= 1_000_000_000 { return String(format: "$%.2fB", v / 1e9) }
        if a >= 1_000_000 { return String(format: "$%.2fM", v / 1e6) }
        if a >= 100_000 { return String(format: "$%.1fK", v / 1e3) }
        let n = NSNumber(value: v.rounded(.down))
        return "$" + (grouping.string(from: n) ?? "\(Int(v))")
    }

    static func gain(_ v: Double) -> String {
        if v < 10 { return String(format: "+$%.1f", v) }
        return "+" + money(v)
    }
}
