import SwiftUI

private struct PanelClose: View {
    @EnvironmentObject var game: GameController
    var body: some View {
        Button {
            game.select(nil)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
    }
}

// MARK: - Station

struct StationPanel: View {
    @EnvironmentObject var game: GameController
    let j: Int

    var body: some View {
        let _ = game.tick
        let d = game.info.dishes[j]
        let st = game.L.stations[j]
        let maxed = st.level >= Rules.maxLevel
        let up = game.upgradeInfo(j)
        let afford = game.s.money >= up.cost
        let rate = Rules.rate(d, level: st.level, cooks: st.cooks)
        let next = Rules.nextMilestone(st.level)
        let prev = Rules.milestones.last { $0 <= st.level } ?? 0
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                DishBadge(dish: d, size: 54)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(d.title).font(.game(18, .heavy)).foregroundColor(.white)
                        Text("Ур. \(st.level)")
                            .font(.game(12, .heavy))
                            .foregroundColor(Pal.ink)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Pal.accent))
                    }
                    if let next {
                        HStack(spacing: 6) {
                            ProgressBar(value: Double(st.level - prev) / Double(next - prev), tint: Color(hex: 0xFF8A65))
                                .frame(height: 6)
                            Text("×2 на \(next)").font(.game(10, .heavy)).foregroundColor(Color(hex: 0xFF8A65))
                        }
                    } else {
                        Text("Максимальная скорость").font(.game(11, .bold)).foregroundColor(Pal.good)
                    }
                }
                PanelClose()
            }
            HStack(spacing: 6) {
                StatTile(icon: "tag.fill", title: "Цена", value: Fmt.money(Rules.price(d, st.level) * game.s.priceMult), tint: Pal.accent)
                StatTile(icon: "speedometer", title: "В минуту", value: rate > 0 ? String(format: rate * 60 >= 100 ? "%.0f" : "%.1f", rate * 60) : "—")
                StatTile(icon: "tray.full.fill", title: "Готово", value: "\(st.stock)/\(Rules.capacity(st.level))",
                         tint: st.stock >= Rules.capacity(st.level) ? Pal.good : .white)
                StatTile(icon: "person.fill", title: "Повара", value: "\(st.cooks)/2")
            }
            if maxed {
                Text("Станция прокачана до максимума!")
                    .font(.game(14, .heavy))
                    .foregroundColor(Pal.good)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .card(14)
            } else {
                HStack(spacing: 8) {
                    BulkPicker()
                    Spacer(minLength: 0)
                    Text("\(Fmt.money(Rules.price(d, st.level))) → \(Fmt.money(Rules.price(d, st.level + up.levels)))")
                        .font(.game(11, .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                PrimaryButton(title: up.levels > 1 ? "Улучшить +\(up.levels)" : "Улучшить",
                              subtitle: Fmt.money(up.cost), icon: "arrow.up.circle.fill",
                              enabled: afford, highlight: game.hud.tutorial == 4 && j == 0) {
                    game.upgradeStation(j)
                }
            }
            if st.cooks < 2 {
                let cost = game.cookCost(j)
                SecondaryButton(title: st.cooks == 0 ? "Нанять повара" : "Второй повар (×1,8 скорость)",
                                subtitle: Fmt.money(cost), icon: "person.fill.badge.plus", tint: Pal.good,
                                enabled: game.s.money >= cost) {
                    game.hireCook(j)
                }
            }
            HStack(spacing: 5) {
                Image(systemName: "hand.tap.fill").font(.system(size: 10, weight: .bold))
                Text("Нажимайте на станцию, чтобы помочь повару").font(.game(11, .semibold))
            }
            .foregroundColor(.white.opacity(0.45))
        }
        .padding(14)
        .glass(22)
    }
}

// MARK: - Locked

struct LockedPanel: View {
    @EnvironmentObject var game: GameController
    let j: Int

    var body: some View {
        let _ = game.tick
        let d = game.info.dishes[j]
        let cost = game.info.stationCosts[j]
        let afford = game.s.money >= cost
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                DishBadge(dish: d, size: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Новое блюдо").font(.game(11, .heavy)).foregroundColor(Pal.accent)
                    Text(d.title).font(.game(20, .heavy)).foregroundColor(.white)
                    Text(d.station).font(.game(12, .semibold)).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                PanelClose()
            }
            HStack(spacing: 6) {
                StatTile(icon: "tag.fill", title: "Цена", value: Fmt.money(d.basePrice * game.s.priceMult), tint: Pal.accent)
                StatTile(icon: "timer", title: "Готовка", value: Fmt.seconds(d.time))
                StatTile(icon: "heart.fill", title: "Спрос", value: d.popularity >= 3 ? "Высокий" : (d.popularity >= 2 ? "Средний" : "Редкий"))
            }
            PrimaryButton(title: "Открыть станцию", subtitle: Fmt.money(cost), icon: "lock.open.fill",
                          enabled: afford, highlight: game.hud.tutorial == 2 && j == 1) {
                game.unlockStation(j)
            }
        }
        .padding(14)
        .glass(22)
    }
}

// MARK: - Counter

struct CounterPanel: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        let _ = game.tick
        let L = game.L
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Pal.info)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Pal.info.opacity(0.15)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Касса и прилавок").font(.game(18, .heavy)).foregroundColor(.white)
                    Text("Кассиры отдают заказы и принимают оплату").font(.game(11, .semibold)).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                PanelClose()
            }
            HStack(spacing: 6) {
                StatTile(icon: "person.crop.circle.fill", title: "Кассир", value: "ур. \(L.cashier)")
                StatTile(icon: "timer", title: "Расчёт", value: Fmt.seconds(Rules.serveTime(L.cashier)), tint: Pal.info)
                StatTile(icon: "door.left.hand.open", title: "Окна", value: "\(L.windows)/\(Rules.maxWindows)")
                StatTile(icon: "person.2.fill", title: "Очередь", value: "\(game.hud.queue)")
            }
            if L.cashier < Rules.maxCashier {
                PrimaryButton(title: "Улучшить кассира", subtitle: Fmt.money(game.cashierCost), icon: "bolt.circle.fill",
                              enabled: game.s.money >= game.cashierCost, highlight: game.hud.tutorial == 6) {
                    game.upgradeCashier()
                }
            }
            if L.windows < Rules.maxWindows {
                SecondaryButton(title: "Открыть окно №\(L.windows + 1)", subtitle: Fmt.money(game.windowCost),
                                icon: "plus.rectangle.on.rectangle", tint: Pal.good, enabled: game.s.money >= game.windowCost) {
                    game.openWindow()
                }
            }
        }
        .padding(14)
        .glass(22)
    }
}

// MARK: - Courier

struct CourierPanel: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        let _ = game.tick
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "scooter")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: 0x81C784))
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color(hex: 0x81C784).opacity(0.15)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Доставка").font(.game(18, .heavy)).foregroundColor(.white)
                    Text("Курьер сам забирает готовую еду со станций").font(.game(11, .semibold)).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                PanelClose()
            }
            if let d = game.sim.runtimes[game.loc].delivery, d.phase < 2 {
                HStack(spacing: 8) {
                    ForEach(Array(d.needs.enumerated()), id: \.offset) { _, item in
                        let have = min(item.1, d.got[item.0, default: 0])
                        HStack(spacing: 6) {
                            Icon3D(dish: item.0, size: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(have)/\(item.1)").font(.game(15, .heavy)).monospacedDigit()
                                    .foregroundColor(have >= item.1 ? Pal.good : .white)
                                ProgressBar(value: Double(have) / Double(item.1), tint: Color(hex: 0x81C784)).frame(height: 5)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .card(12)
                    }
                }
                HStack {
                    Label(d.phase == 0 ? "Курьер в пути" : "Осталось \(Fmt.duration(d.timeLeft))", systemImage: "clock.fill")
                        .font(.game(13, .bold))
                        .foregroundColor(d.timeLeft < 20 ? Pal.bad : .white.opacity(0.8))
                    Spacer()
                    Text("Награда").font(.game(12, .semibold)).foregroundColor(.white.opacity(0.6))
                    MoneyText(value: d.reward * (1 + 0.25 * Double(game.s.level(.courier))), size: 15)
                }
                Text("Подсказка: нажимайте на станции — так еда для заказа будет готова быстрее")
                    .font(.game(11, .semibold))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Заказ закрыт. Новый курьер скоро приедет.")
                    .font(.game(14, .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.vertical, 8)
            }
        }
        .padding(14)
        .glass(22)
    }
}
