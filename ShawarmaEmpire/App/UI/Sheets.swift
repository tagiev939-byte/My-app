import SwiftUI

private struct SheetBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: 0x2A1C14), Pal.sheet], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
    }
}

// MARK: - Upgrades

struct UpgradesSheet: View {
    @EnvironmentObject var game: GameController
    @State private var tab = 0

    var body: some View {
        let _ = game.tick
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Улучшения", icon: "wrench.and.screwdriver.fill")
                HStack(spacing: 6) {
                    ForEach(Array(["Кухня", "Зал и касса"].enumerated()), id: \.offset) { k, t in
                        Button {
                            tab = k
                            Sound.shared.play(.tap, volume: 0.5)
                        } label: {
                            Text(t)
                                .font(.game(14, .heavy))
                                .foregroundColor(tab == k ? Pal.ink : .white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(Capsule().fill(tab == k ? Pal.accent : Color.white.opacity(0.07)))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
                ScrollView {
                    VStack(spacing: 10) {
                        if tab == 0 {
                            HStack {
                                Text("Сколько уровней покупать").font(.game(12, .semibold)).foregroundColor(.white.opacity(0.6))
                                Spacer()
                                BulkPicker()
                            }
                            ForEach(0..<4, id: \.self) { j in StationRow(j: j) }
                        } else {
                            HallRows()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

struct StationRow: View {
    @EnvironmentObject var game: GameController
    let j: Int

    var body: some View {
        let d = game.info.dishes[j]
        let st = game.L.stations[j]
        HStack(spacing: 12) {
            DishBadge(dish: d, size: 48)
                .opacity(st.level > 0 ? 1 : 0.55)
            VStack(alignment: .leading, spacing: 3) {
                Text(d.title).font(.game(15, .heavy)).foregroundColor(.white)
                if st.level > 0 {
                    Text("Ур. \(st.level) · \(Fmt.money(Rules.price(d, st.level))) за шт.")
                        .font(.game(11, .semibold)).foregroundColor(.white.opacity(0.6)).monospacedDigit()
                    if let next = Rules.nextMilestone(st.level) {
                        Text("×2 скорость на ур. \(next)").font(.game(10, .bold)).foregroundColor(Color(hex: 0xFF8A65))
                    }
                } else {
                    Text(d.station).font(.game(11, .semibold)).foregroundColor(.white.opacity(0.6))
                }
            }
            Spacer(minLength: 4)
            if st.level == 0 {
                let cost = game.info.stationCosts[j]
                RowButton(title: "Открыть", cost: cost, enabled: game.s.money >= cost) { game.unlockStation(j) }
            } else if st.level >= Rules.maxLevel {
                Text("MAX").font(.game(14, .black)).foregroundColor(Pal.good).frame(width: 96)
            } else {
                let up = game.upgradeInfo(j)
                RowButton(title: up.levels > 1 ? "+\(up.levels) ур." : "Улучшить", cost: up.cost, enabled: game.s.money >= up.cost) {
                    game.upgradeStation(j)
                }
            }
        }
        .padding(12)
        .card(16)
    }
}

struct RowButton: View {
    let title: String
    let cost: Double
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title).font(.game(12, .heavy))
                Text(Fmt.money(cost)).font(.game(11, .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            }
            .foregroundColor(enabled ? Pal.ink : .white.opacity(0.5))
            .frame(width: 96, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(enabled ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFD45E), Color(hex: 0xF59324)],
                                                                 startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(Color.white.opacity(0.09)))
            )
        }
        .buttonStyle(PressableStyle())
    }
}

struct HallRows: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        let L = game.L
        VStack(spacing: 10) {
            HallRow(icon: "person.crop.circle.badge.checkmark", tint: Pal.info, title: "Кассир",
                    detail: "Ур. \(L.cashier) · расчёт \(Fmt.seconds(Rules.serveTime(L.cashier)))",
                    cost: L.cashier < Rules.maxCashier ? game.cashierCost : nil, action: game.upgradeCashier)
            HallRow(icon: "door.left.hand.open", tint: Pal.good, title: "Окна выдачи",
                    detail: "\(L.windows) из \(Rules.maxWindows) · больше очередей",
                    cost: L.windows < Rules.maxWindows ? game.windowCost : nil, action: game.openWindow)
            HallRow(icon: "megaphone.fill", tint: Color(hex: 0x80DEEA), title: "Реклама района",
                    detail: "Ур. \(L.marketing) · +\(L.marketing * 12)% гостей",
                    cost: L.marketing < Rules.maxMarketing ? game.marketingCost : nil, action: game.buyMarketing)
            HallRow(icon: "sparkles", tint: Color(hex: 0xF48FB1), title: "Декор",
                    detail: L.decor < Rules.maxDecor ? "Далее: \(Rules.decorNames[L.decor])" : "Всё украшено!",
                    cost: L.decor < Rules.maxDecor ? game.decorCost : nil, action: game.buyDecor)
            Text("Декор увеличивает терпение гостей, чаевые и поток клиентов. Столики дают гостям место, чтобы поесть прямо у вас.")
                .font(.game(11, .semibold))
                .foregroundColor(.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }
}

struct HallRow: View {
    @EnvironmentObject var game: GameController
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    let cost: Double?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 48, height: 48)
                .background(Circle().fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.game(15, .heavy)).foregroundColor(.white)
                Text(detail).font(.game(11, .semibold)).foregroundColor(.white.opacity(0.6)).lineLimit(2)
            }
            Spacer(minLength: 4)
            if let cost {
                RowButton(title: "Купить", cost: cost, enabled: game.s.money >= cost, action: action)
            } else {
                Text("MAX").font(.game(14, .black)).foregroundColor(Pal.good).frame(width: 96)
            }
        }
        .padding(12)
        .card(16)
    }
}

// MARK: - City

struct CitySheet: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        let _ = game.tick
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Карта города", icon: "map.fill", tint: Pal.info)
                ScrollView {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            StatTile(icon: "building.2.fill", title: "Точек", value: "\(game.s.unlockedCount)/\(Catalog.locations.count)")
                            StatTile(icon: "chart.line.uptrend.xyaxis", title: "Империя", value: "\(Fmt.money(game.hud.income))/м", tint: Pal.good)
                            StatTile(icon: "star.fill", title: "Звёзды", value: "\(game.s.stars)", tint: Pal.star)
                        }
                        ForEach(Catalog.locations, id: \.id) { info in
                            LocationCard(info: info)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

struct LocationCard: View {
    @EnvironmentObject var game: GameController
    let info: LocationInfo

    var body: some View {
        let state = game.s.locations[info.id]
        let current = game.loc == info.id
        let prevOpen = info.id == 0 || game.s.locations[info.id - 1].unlocked
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: info.theme.accent == 0x1A1A1A ? 0x3A3A3A : info.theme.accent),
                                                      Color(hex: info.theme.trim)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Icon3D(dish: info.dishes[0], size: 46)
                        .opacity(state.unlocked ? 1 : 0.5)
                    if !state.unlocked {
                        Image(systemName: "lock.fill").font(.system(size: 16, weight: .black)).foregroundColor(.white)
                            .offset(x: 18, y: 18)
                    }
                }
                .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(info.name).font(.game(16, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
                        if current {
                            Text("ВЫ ЗДЕСЬ").font(.game(9, .black)).foregroundColor(Pal.ink)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Pal.accent))
                        }
                    }
                    Text(info.blurb).font(.game(11, .semibold)).foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        ForEach(info.dishes, id: \.self) { d in Icon3D(dish: d, size: 22) }
                        Text("×\(Int(info.tier))").font(.game(11, .heavy)).foregroundColor(Pal.accent).padding(.leading, 4)
                    }
                }
            }
            if state.unlocked {
                HStack(spacing: 8) {
                    Label("\(Fmt.money(game.locationIncome(info.id)))/мин", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.game(12, .bold)).foregroundColor(Pal.good)
                    Label(String(format: "%.1f", state.rating), systemImage: "star.fill")
                        .font(.game(12, .bold)).foregroundColor(Pal.star)
                    Spacer()
                    if !current {
                        Button {
                            game.switchLocation(info.id)
                        } label: {
                            Text("Перейти").font(.game(13, .heavy)).foregroundColor(Pal.ink)
                                .padding(.horizontal, 16).frame(height: 34)
                                .background(Capsule().fill(Pal.accent))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            } else {
                PrimaryButton(title: prevOpen ? "Купить точку" : "Сначала откройте предыдущую",
                              subtitle: Fmt.money(info.unlockCost), icon: "key.fill",
                              enabled: prevOpen && game.s.money >= info.unlockCost) {
                    if prevOpen { game.buyLocation(info.id) }
                }
            }
        }
        .padding(12)
        .card(18)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(current ? Pal.accent.opacity(0.6) : .clear, lineWidth: 1.5))
    }
}

// MARK: - Empire

struct EmpireSheet: View {
    @EnvironmentObject var game: GameController
    @State private var confirm = false

    var body: some View {
        let _ = game.tick
        let gain = game.s.potentialStars
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Империя", icon: "crown.fill", tint: Pal.star)
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(GlobalUpgrade.allCases, id: \.self) { u in
                            let lv = game.s.level(u)
                            HStack(spacing: 12) {
                                Image(systemName: u.icon)
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundColor(Pal.star)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(Pal.star.opacity(0.14)))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(u.title).font(.game(15, .heavy)).foregroundColor(.white)
                                    Text(u.info).font(.game(11, .semibold)).foregroundColor(.white.opacity(0.6))
                                    HStack(spacing: 3) {
                                        ForEach(0..<u.maxLevel, id: \.self) { k in
                                            Capsule().fill(k < lv ? Pal.star : Color.white.opacity(0.12)).frame(width: 12, height: 5)
                                        }
                                    }
                                }
                                Spacer(minLength: 4)
                                if lv < u.maxLevel {
                                    RowButton(title: "Купить", cost: u.cost(lv), enabled: game.s.money >= u.cost(lv)) { game.buyGlobal(u) }
                                } else {
                                    Text("MAX").font(.game(14, .black)).foregroundColor(Pal.good).frame(width: 96)
                                }
                            }
                            .padding(12)
                            .card(16)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "star.circle.fill").font(.system(size: 30, weight: .bold)).foregroundColor(Pal.star)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Франшиза").font(.game(18, .heavy)).foregroundColor(.white)
                                    Text("У вас \(game.s.stars) ★ · цены +\(game.s.stars * 10)%")
                                        .font(.game(12, .bold)).foregroundColor(Pal.star)
                                }
                            }
                            Text("Продайте сеть инвесторам: все точки и деньги сбросятся, а за каждые заработанные миллионы вы получите звёзды. Каждая ★ навсегда даёт +10% к ценам.")
                                .font(.game(12, .semibold))
                                .foregroundColor(.white.opacity(0.65))
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Text("Заработано за всё время").font(.game(12, .semibold)).foregroundColor(.white.opacity(0.6))
                                Spacer()
                                MoneyText(value: game.s.lifetimeEarned, size: 13)
                            }
                            PrimaryButton(title: gain > 0 ? "Продать франшизу: +\(gain) ★" : "Пока рано",
                                          subtitle: gain > 0 ? nil : "Первая звезда — после $10K за всё время",
                                          icon: "sparkles", enabled: gain > 0) {
                                if gain > 0 { confirm = true }
                            }
                        }
                        .padding(14)
                        .card(18)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Pal.star.opacity(0.35), lineWidth: 1))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .confirmationDialog("Продать франшизу? Все точки и деньги сбросятся, но вы получите \(gain) ★.",
                            isPresented: $confirm, titleVisibility: .visible) {
            Button("Продать за \(gain) ★", role: .destructive) { game.franchise() }
            Button("Отмена", role: .cancel) {}
        }
    }
}

// MARK: - Quests

struct QuestsSheet: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        let _ = game.tick
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Задания", icon: "checklist", tint: Pal.good)
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(game.s.quests) { q in
                            QuestRow(q: q)
                        }
                        HStack(spacing: 8) {
                            StatTile(icon: "checkmark.seal.fill", title: "Выполнено", value: "\(game.s.questsDone)", tint: Pal.good)
                            StatTile(icon: "person.3.fill", title: "Гостей", value: "\(game.s.served)")
                            StatTile(icon: "scooter", title: "Доставок", value: "\(game.s.deliveries)")
                        }
                        Text("Новые задания появляются сразу после получения награды.")
                            .font(.game(11, .semibold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

struct QuestRow: View {
    @EnvironmentObject var game: GameController
    let q: Quest

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: q.kind.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(q.done ? Pal.good : Pal.accent)
                .frame(width: 46, height: 46)
                .background(Circle().fill((q.done ? Pal.good : Pal.accent).opacity(0.15)))
            VStack(alignment: .leading, spacing: 5) {
                Text(q.kind.text(q.target)).font(.game(14, .bold)).foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ProgressBar(value: q.fraction, tint: q.done ? Pal.good : Pal.accent).frame(height: 6)
                    Text(progressText).font(.game(10, .heavy)).foregroundColor(.white.opacity(0.6)).monospacedDigit()
                }
            }
            Spacer(minLength: 4)
            Button {
                game.claimQuest(q.id)
            } label: {
                VStack(spacing: 1) {
                    Text(q.done ? "Забрать" : "Награда").font(.game(11, .heavy))
                    Text(Fmt.money(q.reward)).font(.game(12, .heavy)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                }
                .foregroundColor(q.done ? Pal.ink : .white.opacity(0.7))
                .frame(width: 84, height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(q.done ? AnyShapeStyle(Pal.good) : AnyShapeStyle(Color.white.opacity(0.08))))
            }
            .buttonStyle(PressableStyle())
            .disabled(!q.done)
        }
        .padding(12)
        .card(16)
    }

    private var progressText: String {
        switch q.kind {
        case .earn: return "\(Fmt.money(min(q.progress, q.target)))"
        case .rating: return String(format: "%.1f", q.progress)
        default: return "\(Int(min(q.progress, q.target)))/\(Int(q.target))"
        }
    }
}

// MARK: - Menu

struct MenuSheet: View {
    @EnvironmentObject var game: GameController
    @State private var confirmNew = false

    var body: some View {
        let _ = game.tick
        let s = game.s
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Шаурма Империя", icon: "fork.knife", tint: Pal.accent)
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Доход за последние 20 минут").font(.game(13, .heavy)).foregroundColor(.white.opacity(0.8))
                            IncomeChart(values: s.history)
                                .frame(height: 110)
                        }
                        .padding(14)
                        .card(18)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            StatTile(icon: "person.3.fill", title: "Гостей", value: "\(s.served)")
                            StatTile(icon: "face.smiling", title: "Довольны", value: s.served + s.angry > 0
                                     ? "\(Int(Double(s.served) / Double(s.served + s.angry) * 100))%" : "—", tint: Pal.good)
                            StatTile(icon: "scooter", title: "Доставок", value: "\(s.deliveries)")
                            StatTile(icon: "banknote.fill", title: "Всего", value: Fmt.money(s.lifetimeEarned), tint: Pal.accent)
                            StatTile(icon: "star.fill", title: "Франшиз", value: "\(s.franchises)", tint: Pal.star)
                            StatTile(icon: "clock.fill", title: "В игре", value: Fmt.duration(s.playTime))
                        }

                        VStack(spacing: 0) {
                            SettingToggle(icon: "music.note", title: "Музыка", isOn: $game.musicOn)
                            Divider().background(Color.white.opacity(0.08))
                            SettingToggle(icon: "speaker.wave.2.fill", title: "Звуки", isOn: $game.soundOn)
                            Divider().background(Color.white.opacity(0.08))
                            SettingToggle(icon: "iphone.radiowaves.left.and.right", title: "Вибрация", isOn: $game.hapticsOn)
                            Divider().background(Color.white.opacity(0.08))
                            SettingToggle(icon: "sparkles.tv.fill", title: "Высокое качество графики", isOn: $game.highQuality)
                        }
                        .card(18)

                        SecondaryButton(title: "Вернуть камеру", icon: "camera.viewfinder", tint: Pal.info) {
                            game.resetCamera()
                            game.sheet = nil
                        }
                        SecondaryButton(title: "Начать заново", icon: "arrow.counterclockwise", tint: Pal.bad) {
                            confirmNew = true
                        }
                        Text("Версия 1.0 · Сделано с любовью к шаурме")
                            .font(.game(11, .semibold))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .confirmationDialog("Начать заново? Весь прогресс будет удалён.", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("Начать заново", role: .destructive) {
                game.sheet = nil
                game.newGame()
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}

struct SettingToggle: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundColor(Pal.accent).frame(width: 24)
                Text(title).font(.game(14, .semibold)).foregroundColor(.white)
            }
        }
        .tint(Pal.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct IncomeChart: View {
    let values: [Double]

    var body: some View {
        GeometryReader { g in
            let data = values.isEmpty ? [0] : Array(values.suffix(40))
            let maxV = max(data.max() ?? 1, 1)
            let w = g.size.width / CGFloat(max(data.count, 1))
            ZStack(alignment: .bottomLeading) {
                ForEach(0..<4, id: \.self) { k in
                    Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                        .offset(y: -g.size.height * CGFloat(k) / 3)
                }
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.offset) { i, v in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(LinearGradient(colors: [Pal.accent, Pal.accentDeep], startPoint: .top, endPoint: .bottom))
                            .frame(width: max(2, w - 3), height: max(2, g.size.height * CGFloat(v / maxV)))
                            .opacity(i == data.count - 1 ? 1 : 0.75)
                            .frame(width: w)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                Text("\(Fmt.money(maxV))/мин").font(.game(10, .bold)).foregroundColor(.white.opacity(0.5))
            }
        }
    }
}
