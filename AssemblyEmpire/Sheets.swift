import SwiftUI

struct SheetHeader: View {
    let title: String
    let icon: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(Theme.accent)
            Text(title).font(.system(size: 22, weight: .heavy, design: .rounded))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }
}

struct SheetBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: 0x18212D), Color(hex: 0x0E141C)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// MARK: - Goals

struct GoalsSheet: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Цели", icon: "flag.checkered")
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(Goal.all.enumerated()), id: \.offset) { i, g in
                            GoalRow(goal: g, index: i, state: i < store.goalIndex ? .done : (i == store.goalIndex ? .active : .locked),
                                    progress: i == store.goalIndex ? store.goalProgress : 0,
                                    current: i == store.goalIndex ? g.current(store.world) : 0)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

enum GoalState { case done, active, locked }

struct GoalRow: View {
    let goal: Goal
    let index: Int
    let state: GoalState
    let progress: Double
    let current: Double

    var unlockText: String? {
        let names = BuildingType.allCases.filter { $0.unlockGoal == index }.map { $0.title }
        return names.isEmpty ? nil : "Открывает: " + names.joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(state == .done ? Theme.good.opacity(0.2) : Color.white.opacity(0.07))
                switch state {
                case .done:
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundColor(Theme.good)
                case .active:
                    if let i = goal.icon { ItemIcon(item: i, size: 24) } else {
                        Image(systemName: "dollarsign").font(.system(size: 15, weight: .heavy)).foregroundColor(Theme.accent)
                    }
                case .locked:
                    Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(goal.title).font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Text(Fmt.gain(goal.reward))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.accent)
                }
                Text(goal.detail)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                if let u = unlockText {
                    Text(u)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: 0x8AB4F8))
                }
                if state == .active {
                    ProgressBar(value: progress).frame(height: 7)
                    Text(progressText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .foregroundColor(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(state == .active ? Theme.accent.opacity(0.08) : Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(state == .active ? Theme.accent.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1))
        .opacity(state == .locked ? 0.55 : 1)
    }

    var progressText: String {
        switch goal.kind {
        case .earn: return "\(Fmt.money(current)) из \(Fmt.money(goal.target))"
        default: return "\(Int(current)) из \(Int(goal.target))"
        }
    }
}

// MARK: - Upgrades

struct UpgradesSheet: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Улучшения", icon: "bolt.fill")
                HStack {
                    CoinView(size: 20)
                    Text(Fmt.money(store.money))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(UpgradeType.allCases, id: \.self) { u in
                            UpgradeRow(upgrade: u)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct UpgradeRow: View {
    @EnvironmentObject var store: GameStore
    let upgrade: UpgradeType

    var body: some View {
        let level = store.world.level(upgrade)
        let maxed = level >= upgrade.maxLevel
        let cost = upgrade.cost(level: level)
        let affordable = store.money >= cost

        HStack(spacing: 14) {
            Image(systemName: upgrade.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.accent)
                .frame(width: 46, height: 46)
                .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(upgrade.title).font(.system(size: 16, weight: .bold, design: .rounded))
                Text(upgrade.info).font(.system(size: 12, design: .rounded)).foregroundColor(.white.opacity(0.65))
                HStack(spacing: 3) {
                    ForEach(0..<upgrade.maxLevel, id: \.self) { i in
                        Capsule()
                            .fill(i < level ? Theme.accent : Color.white.opacity(0.12))
                            .frame(width: 14, height: 5)
                    }
                }
            }
            Spacer()
            Button { store.buy(upgrade) } label: {
                Text(maxed ? "МАКС" : Fmt.money(cost))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(maxed ? .white.opacity(0.5) : (affordable ? .black : .white.opacity(0.6)))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(maxed ? Color.white.opacity(0.08) : (affordable ? Theme.accent : Color.white.opacity(0.1))))
            }
            .buttonStyle(.plain)
            .disabled(maxed)
        }
        .foregroundColor(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Menu

struct MenuSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Assembly Empire", icon: "building.2.fill")
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(spacing: 10) {
                            StatRow(title: "Заработано всего", value: Fmt.money(store.world.totalEarned))
                            StatRow(title: "Доход", value: "\(Fmt.money(store.income)) / мин")
                            StatRow(title: "Построек", value: "\(store.world.buildingCount)")
                            StatRow(title: "Продано предметов", value: "\(store.world.sold.values.reduce(0, +))")
                            StatRow(title: "Время в игре", value: timeString(store.world.time))
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))

                        MenuButton(title: "Как играть", icon: "questionmark.circle.fill", tint: .white) {
                            store.sheet = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { store.sheet = .help }
                        }
                        MenuButton(title: "Сохранить", icon: "square.and.arrow.down.fill", tint: .white) {
                            store.save()
                            store.showToast("Игра сохранена", icon: "checkmark.circle.fill", tint: Theme.good)
                            dismiss()
                        }
                        MenuButton(title: "Новая игра", icon: "arrow.counterclockwise", tint: Theme.bad) {
                            confirmReset = true
                        }

                        Text("Игра сохраняется автоматически")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                            .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .confirmationDialog("Начать заново? Весь прогресс будет потерян.", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Новая игра", role: .destructive) {
                store.newGame()
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    func timeString(_ t: Double) -> String {
        let s = Int(t)
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h) ч \(m) мин" : "\(m) мин \(s % 60) с"
    }
}

struct StatRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title).foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value).fontWeight(.bold).monospacedDigit().foregroundColor(.white)
        }
        .font(.system(size: 14, design: .rounded))
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title).fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).opacity(0.4)
            }
            .font(.system(size: 16, design: .rounded))
            .foregroundColor(tint)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Help

struct HelpSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    private let steps: [(BuildingType?, String, String)] = [
        (.miner, "Добыча", "Выберите «Бур» и нажмите на цветную залежь. Белая стрелка показывает, куда бур выдаёт руду."),
        (.belt, "Конвейеры", "Выберите «Конвейер» и проведите пальцем — линия проложится сама и повернёт за пальцем."),
        (.seller, "Продажа", "Поставьте «Рынок» в конце линии. Всё, что туда приедет, превратится в деньги."),
        (.smelter, "Переработка", "Печь превращает руду в пластины — они стоят в 4 раза дороже. Рецепт меняется в карточке постройки."),
        (.assembler, "Производство", "Сборщик делает шестерни, провода, микросхемы и моторы. Сложные детали приносят огромные деньги."),
        (nil, "Управление", "Двигайте карту пальцем в режиме «Осмотр», приближайте щипком. Нажатие на постройку открывает её карточку."),
    ]

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Как играть", icon: "questionmark.circle.fill")
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Постройте фабричную империю: добывайте руду, перерабатывайте её и продавайте всё более сложные товары.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                            HStack(alignment: .top, spacing: 12) {
                                Group {
                                    if let t = s.0 {
                                        BuildingIcon(type: t, dir: .right, size: 42)
                                    } else {
                                        Image(systemName: "hand.draw.fill")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                            .frame(width: 42, height: 42)
                                            .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(i + 1). \(s.1)").font(.system(size: 16, weight: .bold, design: .rounded))
                                    Text(s.2).font(.system(size: 13, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .foregroundColor(.white)
                        }

                        Button {
                            store.finishTutorial()
                            dismiss()
                        } label: {
                            Text("Начать строить")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
        }
        .presentationDetents([.large])
        .onDisappear { store.finishTutorial() }
    }
}
