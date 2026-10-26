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

// MARK: - Dishes

enum Appliance {
    case spit, fryer, drinks, grill, roller, machine, oven, blender, display, pot
}

enum Dish: String, CaseIterable, Codable {
    case shawarma, cola, fries, shawarmaXL
    case burger, hotdog, tea, donut
    case pizza, nuggets, milkshake, icecream
    case plov, steak, lemonade, cheesecake
    case sushi, ramen, coffee, cake

    var title: String {
        switch self {
        case .shawarma: return "Шаурма"
        case .cola: return "Кола"
        case .fries: return "Картошка фри"
        case .shawarmaXL: return "Шаурма XL"
        case .burger: return "Бургер"
        case .hotdog: return "Хот-дог"
        case .tea: return "Чай"
        case .donut: return "Пончик"
        case .pizza: return "Пицца"
        case .nuggets: return "Наггетсы"
        case .milkshake: return "Молочный коктейль"
        case .icecream: return "Мороженое"
        case .plov: return "Плов"
        case .steak: return "Стейк"
        case .lemonade: return "Лимонад"
        case .cheesecake: return "Чизкейк"
        case .sushi: return "Суши"
        case .ramen: return "Рамен"
        case .coffee: return "Кофе"
        case .cake: return "Торт"
        }
    }

    var station: String {
        switch appliance {
        case .spit: return "Вертел"
        case .fryer: return "Фритюрница"
        case .drinks: return "Автомат напитков"
        case .grill: return "Гриль"
        case .roller: return "Роликовый гриль"
        case .machine: return "Кофемашина"
        case .oven: return "Печь"
        case .blender: return "Блендер"
        case .display: return "Витрина"
        case .pot: return "Казан"
        }
    }

    var basePrice: Double {
        switch self {
        case .shawarma: return 6
        case .cola: return 3
        case .fries: return 5
        case .shawarmaXL: return 16
        case .burger: return 30
        case .hotdog: return 22
        case .tea: return 12
        case .donut: return 40
        case .pizza: return 220
        case .nuggets: return 130
        case .milkshake: return 90
        case .icecream: return 160
        case .plov: return 1_500
        case .steak: return 2_400
        case .lemonade: return 700
        case .cheesecake: return 1_800
        case .sushi: return 12_000
        case .ramen: return 15_000
        case .coffee: return 5_000
        case .cake: return 18_000
        }
    }

    /// Seconds to cook one portion at level 1 with one cook.
    var time: Double {
        switch self {
        case .shawarma: return 3.0
        case .cola: return 1.6
        case .fries: return 2.4
        case .shawarmaXL: return 5.0
        case .burger: return 3.5
        case .hotdog: return 2.6
        case .tea: return 1.6
        case .donut: return 4.0
        case .pizza: return 6.0
        case .nuggets: return 3.0
        case .milkshake: return 2.5
        case .icecream: return 3.5
        case .plov: return 6.0
        case .steak: return 7.0
        case .lemonade: return 2.5
        case .cheesecake: return 5.0
        case .sushi: return 6.0
        case .ramen: return 7.0
        case .coffee: return 2.5
        case .cake: return 6.0
        }
    }

    var appliance: Appliance {
        switch self {
        case .shawarma, .shawarmaXL: return .spit
        case .fries, .nuggets: return .fryer
        case .cola, .lemonade: return .drinks
        case .burger, .steak: return .grill
        case .hotdog: return .roller
        case .tea, .coffee: return .machine
        case .pizza: return .oven
        case .milkshake: return .blender
        case .donut, .icecream, .cheesecake, .sushi, .cake: return .display
        case .plov, .ramen: return .pot
        }
    }

    var hex: UInt32 {
        switch self {
        case .shawarma: return 0xE9B872
        case .cola: return 0xD32F2F
        case .fries: return 0xF6C343
        case .shawarmaXL: return 0xD9822B
        case .burger: return 0xB5651D
        case .hotdog: return 0xE07A3F
        case .tea: return 0x8D5A2B
        case .donut: return 0xF48FB1
        case .pizza: return 0xE65100
        case .nuggets: return 0xE0A040
        case .milkshake: return 0xF8BBD0
        case .icecream: return 0xFFF59D
        case .plov: return 0xE5A13A
        case .steak: return 0x8D3B2B
        case .lemonade: return 0xFFEB3B
        case .cheesecake: return 0xFFE0B2
        case .sushi: return 0xFF8A65
        case .ramen: return 0xF4A261
        case .coffee: return 0x6D4C41
        case .cake: return 0xF06292
        }
    }

    /// Weight in customer orders.
    var popularity: Double {
        switch self {
        case .shawarma, .burger, .pizza, .plov, .sushi: return 3
        case .shawarmaXL, .donut, .icecream, .cheesecake, .cake: return 1.4
        default: return 2
        }
    }

    var color: Color { Color(hex: hex) }
    var iconKey: String { "dish." + rawValue }
}

// MARK: - Locations

enum Backdrop {
    case metro, university, mall, river, city
}

struct Theme {
    let floorA: UInt32
    let floorB: UInt32
    let wall: UInt32
    let trim: UInt32
    let accent: UInt32
    let accent2: UInt32
    let signColor: UInt32
    let counter: UInt32
    let backdrop: Backdrop
}

struct LocationInfo {
    let id: Int
    let name: String
    let sign: String
    let dishes: [Dish]
    let unlockCost: Double
    let stationCosts: [Double]
    let tier: Double
    let theme: Theme
    let blurb: String
}

enum Catalog {
    static let locations: [LocationInfo] = [
        LocationInfo(id: 0, name: "Ларёк у метро", sign: "ШАУРМА",
                     dishes: [.shawarma, .cola, .fries, .shawarmaXL],
                     unlockCost: 0, stationCosts: [0, 60, 350, 1_800], tier: 1,
                     theme: Theme(floorA: 0xE8D9C0, floorB: 0xD7C3A1, wall: 0xF3E6CF, trim: 0x8B5A2B,
                                  accent: 0xD32F2F, accent2: 0xFFF3E0, signColor: 0xFFD54F, counter: 0xB23B2E,
                                  backdrop: .metro),
                     blurb: "Маленький ларёк у выхода из метро. Отсюда начинается империя."),
        LocationInfo(id: 1, name: "Кафе «Студент»", sign: "СТУДЕНТ",
                     dishes: [.burger, .hotdog, .tea, .donut],
                     unlockCost: 25_000, stationCosts: [0, 4_000, 15_000, 60_000], tier: 5,
                     theme: Theme(floorA: 0xDCE8D2, floorB: 0xC5D8B6, wall: 0xB5533C, trim: 0x5D4037,
                                  accent: 0x2E7D32, accent2: 0xF1F8E9, signColor: 0xC5E1A5, counter: 0x33691E,
                                  backdrop: .university),
                     blurb: "Кафе напротив университета. Студенты всегда голодные."),
        LocationInfo(id: 2, name: "Фудкорт «Галерея»", sign: "ГАЛЕРЕЯ",
                     dishes: [.pizza, .nuggets, .milkshake, .icecream],
                     unlockCost: 700_000, stationCosts: [0, 120_000, 450_000, 1_800_000], tier: 25,
                     theme: Theme(floorA: 0xECE6F5, floorB: 0xD7CDEA, wall: 0xF5F3FA, trim: 0x4527A0,
                                  accent: 0x5E35B1, accent2: 0xEDE7F6, signColor: 0xB39DDB, counter: 0x4527A0,
                                  backdrop: .mall),
                     blurb: "Точка в огромном торговом центре. Поток покупателей не кончается."),
        LocationInfo(id: 3, name: "Ресторан «Набережная»", sign: "НАБЕРЕЖНАЯ",
                     dishes: [.plov, .steak, .lemonade, .cheesecake],
                     unlockCost: 20_000_000, stationCosts: [0, 3_000_000, 12_000_000, 45_000_000], tier: 250,
                     theme: Theme(floorA: 0xC8A27A, floorB: 0xB68B62, wall: 0xF0E6D8, trim: 0x00695C,
                                  accent: 0x00796B, accent2: 0xE0F2F1, signColor: 0x80CBC4, counter: 0x004D40,
                                  backdrop: .river),
                     blurb: "Летняя веранда у реки с огоньками. Здесь гуляет весь город."),
        LocationInfo(id: 4, name: "Флагман в Сити", sign: "ИМПЕРИЯ",
                     dishes: [.sushi, .ramen, .coffee, .cake],
                     unlockCost: 500_000_000, stationCosts: [0, 80_000_000, 300_000_000, 1_200_000_000], tier: 2_000,
                     theme: Theme(floorA: 0x2B2B2B, floorB: 0x1F1F1F, wall: 0x262626, trim: 0xC9A227,
                                  accent: 0x1A1A1A, accent2: 0xFFC107, signColor: 0xFFD54F, counter: 0x111111,
                                  backdrop: .city),
                     blurb: "Флагманский ресторан среди небоскрёбов. Вершина империи."),
    ]
}

// MARK: - Rules & formulas

enum Rules {
    static let maxLevel = 100
    static let milestones = [10, 25, 50, 75, 100]
    static let dayLength: Double = 420

    static func speedMult(_ level: Int) -> Double {
        pow(2, Double(milestones.filter { level >= $0 }.count))
    }

    static func nextMilestone(_ level: Int) -> Int? { milestones.first { $0 > level } }

    static func price(_ d: Dish, _ level: Int) -> Double {
        d.basePrice * (1 + 0.15 * Double(max(1, level) - 1))
    }

    static func rate(_ d: Dish, level: Int, cooks: Int) -> Double {
        guard cooks > 0, level > 0 else { return 0 }
        return speedMult(level) * (cooks >= 2 ? 1.8 : 1) / d.time
    }

    static func capacity(_ level: Int) -> Int { min(12, 4 + level / 10) }

    static func upgradeCost(_ d: Dish, _ level: Int) -> Double {
        (d.basePrice * 5 * pow(1.105, Double(level - 1))).rounded()
    }

    /// Cost of `count` levels starting at `level`; `count == 0` means as many as affordable.
    static func bulk(_ d: Dish, level: Int, count: Int, money: Double) -> (levels: Int, cost: Double) {
        var lv = level, total = 0.0, n = 0
        while lv < maxLevel {
            let c = upgradeCost(d, lv)
            if count == 0 {
                if total + c > money { break }
            } else if n >= count {
                break
            }
            total += c
            lv += 1
            n += 1
        }
        return (n, total)
    }

    static func cookCost(_ d: Dish) -> Double { (d.basePrice * 150).rounded() }

    static let maxWindows = 3
    static func windowCost(_ tier: Double, opening n: Int) -> Double { n == 2 ? 350 * tier : 3_500 * tier }

    static let maxCashier = 25
    static func serveTime(_ cashier: Int) -> Double { 1.8 / (1 + 0.15 * Double(cashier - 1)) }
    static func cashierCost(_ tier: Double, _ level: Int) -> Double { (60 * tier * pow(1.28, Double(level - 1))).rounded() }

    static let maxMarketing = 25
    static func marketingCost(_ tier: Double, _ level: Int) -> Double { (120 * tier * pow(1.32, Double(level))).rounded() }

    static let maxDecor = 10
    static func decorCost(_ tier: Double, _ level: Int) -> Double { (250 * tier * pow(1.7, Double(level))).rounded() }

    static let decorNames = [
        "Цветы в горшках", "Меню-штендер", "Столик слева", "Столик справа", "Гирлянды",
        "Неоновая рамка", "Клумбы", "Зонтики", "Гигантская скульптура", "Золотой стандарт",
    ]

    /// Customer flow over the day (dayTime 0...1).
    static func dayFactor(_ t: Double) -> Double {
        switch t {
        case ..<0.06: return 0.55
        case ..<0.30: return 0.95
        case ..<0.45: return 1.7
        case ..<0.65: return 1.0
        case ..<0.78: return 1.25
        default: return 0.55
        }
    }

    static func isRush(_ t: Double) -> Bool { t >= 0.30 && t < 0.45 }

    static func nightFactor(_ t: Double) -> Double {
        switch t {
        case ..<0.06: return 1 - t / 0.06
        case ..<0.70: return 0
        case ..<0.80: return (t - 0.70) / 0.10
        default: return 1
        }
    }

    /// Clock shown in the HUD: dayTime 0 = 06:00.
    static func clock(_ t: Double) -> String {
        let minutes = Int((t * 24 * 60 + 6 * 60).truncatingRemainder(dividingBy: 24 * 60))
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    static func franchiseStars(lifetime: Double) -> Int {
        Int((10 * sqrt(max(0, lifetime) / 1_000_000)).rounded(.down))
    }
}

// MARK: - Global upgrades

enum GlobalUpgrade: String, CaseIterable, Codable {
    case ads, sauce, night, courier

    var title: String {
        switch self {
        case .ads: return "Реклама по городу"
        case .sauce: return "Фирменный соус"
        case .night: return "Ночная смена"
        case .courier: return "Курьерская служба"
        }
    }

    var info: String {
        switch self {
        case .ads: return "+8% клиентов во всех точках"
        case .sauce: return "+10% к ценам всех блюд"
        case .night: return "+1 час дохода, пока игра закрыта"
        case .courier: return "+25% к наградам за доставки"
        }
    }

    var icon: String {
        switch self {
        case .ads: return "megaphone.fill"
        case .sauce: return "drop.fill"
        case .night: return "moon.stars.fill"
        case .courier: return "scooter"
        }
    }

    var maxLevel: Int {
        switch self {
        case .ads, .sauce: return 10
        case .night, .courier: return 5
        }
    }

    func cost(_ level: Int) -> Double {
        let base: Double
        switch self {
        case .ads: base = 1_500
        case .sauce: base = 3_000
        case .night: base = 2_000
        case .courier: base = 2_500
        }
        return (base * pow(3.2, Double(level))).rounded()
    }
}

// MARK: - Quests

enum QuestKind: String, Codable, CaseIterable {
    case serve, earn, upgrade, tap, delivery, rating

    func text(_ target: Double) -> String {
        switch self {
        case .serve: return "Обслужите \(Int(target)) клиентов"
        case .earn: return "Заработайте \(Fmt.money(target))"
        case .upgrade: return "Улучшите станции \(Int(target)) раз"
        case .tap: return "Помогите поварам: \(Int(target)) нажатий"
        case .delivery: return "Выполните доставки: \(Int(target))"
        case .rating: return String(format: "Поднимите рейтинг до %.1f", target)
        }
    }

    var icon: String {
        switch self {
        case .serve: return "person.3.fill"
        case .earn: return "dollarsign.circle.fill"
        case .upgrade: return "arrow.up.circle.fill"
        case .tap: return "hand.tap.fill"
        case .delivery: return "scooter"
        case .rating: return "star.fill"
        }
    }
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
        if a >= 1e15 { return sign + String(format: "$%.2fQ", a / 1e15) }
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

    static func seconds(_ s: Double) -> String {
        s < 10 ? String(format: "%.1f с", s) : String(format: "%.0f с", s)
    }
}
