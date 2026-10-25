import SwiftUI
import Charts

struct SheetHeader: View {
    let title: String
    let icon: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(Theme.accent)
            Text(title).font(.game(24, .heavy))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(PressableStyle())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 6)
    }
}

struct SheetBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: 0x1A2533), Color(hex: 0x0D131B)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// MARK: - Goals

enum GoalState { case done, active, locked }

struct GoalsSheet: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Цели", icon: "flag.checkered")
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(Goal.all.enumerated()), id: \.offset) { i, g in
                                let state: GoalState = i < game.hud.goalIndex ? .done : (i == game.hud.goalIndex ? .active : .locked)
                                GoalRow(goal: g, index: i, state: state,
                                        progress: state == .active ? game.hud.goalProgress : 0,
                                        current: state == .active ? game.world.goalValue(g) : 0)
                                    .id(i)
                            }
                        }
                        .padding(20)
                    }
                    .onAppear { proxy.scrollTo(game.hud.goalIndex, anchor: .center) }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

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
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .heavy)).foregroundColor(Theme.good)
                case .active:
                    if let key = goal.iconKey {
                        Icon3D(key: key, size: 34)
                    } else {
                        Image(systemName: goal.symbol).font(.system(size: 16, weight: .heavy)).foregroundColor(Theme.accent)
                    }
                case .locked:
                    Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(goal.title).font(.game(16, .bold))
                    Spacer()
                    Text(Fmt.gain(goal.reward)).font(.game(13, .heavy)).foregroundColor(Theme.accent)
                }
                Text(goal.detail)
                    .font(.game(13, .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                if let u = unlockText {
                    Label(u, systemImage: "lock.open.fill")
                        .font(.game(12, .semibold))
                        .foregroundColor(Theme.info)
                }
                if state == .active {
                    ProgressBar(value: progress).frame(height: 7)
                    Text(progressText).font(.game(11, .semibold)).monospacedDigit().foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .foregroundColor(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(state == .active ? Theme.accent.opacity(0.09) : Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(state == .active ? Theme.accent.opacity(0.55) : Color.white.opacity(0.06), lineWidth: 1))
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
    @EnvironmentObject var game: GameController

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Исследования", icon: "bolt.circle.fill")
                HStack(spacing: 8) {
                    CoinView(size: 22)
                    Text(Fmt.money(game.hud.money)).font(.game(17, .heavy)).monospacedDigit().foregroundColor(.white)
                    Spacer()
                    Text("Улучшения действуют на всю фабрику")
                        .font(.game(11, .medium)).foregroundColor(.white.opacity(0.5))
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
        .presentationDragIndicator(.visible)
    }
}

struct UpgradeRow: View {
    @EnvironmentObject var game: GameController
    let upgrade: UpgradeType

    var body: some View {
        let level = game.world.upgradeLevel(upgrade)
        let maxed = level >= upgrade.maxLevel
        let cost = upgrade.cost(level: level)
        let affordable = game.hud.money >= cost
        let _ = game.tick

        HStack(spacing: 14) {
            Image(systemName: upgrade.icon)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(Theme.accent)
                .frame(width: 50, height: 50)
                .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(upgrade.title).font(.game(16, .bold))
                Text(upgrade.info).font(.game(12, .regular)).foregroundColor(.white.opacity(0.65))
                HStack(spacing: 3) {
                    ForEach(0..<upgrade.maxLevel, id: \.self) { i in
                        Capsule().fill(i < level ? Theme.accent : Color.white.opacity(0.12)).frame(width: 13, height: 5)
                    }
                }
            }
            Spacer(minLength: 4)
            Button { game.buyUpgrade(upgrade) } label: {
                Text(maxed ? "МАКС" : Fmt.money(cost))
                    .font(.game(13, .heavy)).monospacedDigit()
                    .foregroundColor(maxed ? .white.opacity(0.5) : (affordable ? Theme.ink : .white.opacity(0.6)))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(maxed ? Color.white.opacity(0.08) : (affordable ? Theme.accent : Color.white.opacity(0.1))))
            }
            .buttonStyle(PressableStyle())
            .disabled(maxed)
        }
        .foregroundColor(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Menu

struct MenuSheet: View {
    @EnvironmentObject var game: GameController
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        let w = game.world
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Империя", icon: "building.2.fill")
                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Доход в минуту").font(.game(13, .bold)).foregroundColor(.white.opacity(0.6))
                            let values = w.history + [game.hud.income]
                            let data = values.indices.map { ChartPoint(id: $0, value: values[$0]) }
                            Chart(data) { p in
                                AreaMark(x: .value("t", p.id), y: .value("$", p.value))
                                    .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.45), Theme.accent.opacity(0.02)],
                                                                    startPoint: .top, endPoint: .bottom))
                                    .interpolationMethod(.catmullRom)
                                LineMark(x: .value("t", p.id), y: .value("$", p.value))
                                    .foregroundStyle(Theme.accent)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                                    .interpolationMethod(.catmullRom)
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis { AxisMarks(position: .leading) }
                            .frame(height: 130)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))

                        VStack(spacing: 10) {
                            StatRow(title: "Заработано всего", value: Fmt.money(w.totalEarned))
                            StatRow(title: "Доход", value: "\(Fmt.money(game.hud.income)) / мин")
                            StatRow(title: "Построек", value: "\(w.buildingCount)")
                            StatRow(title: "Участков", value: "\(w.ownedCount) из \(World.chunks * World.chunks)")
                            StatRow(title: "Продано товаров", value: "\(w.sold.values.reduce(0, +))")
                            StatRow(title: "Время в игре", value: Fmt.duration(w.time))
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))

                        VStack(spacing: 4) {
                            Toggle(isOn: $game.soundOn) { Label("Звук", systemImage: "speaker.wave.2.fill") }
                            Divider().overlay(Color.white.opacity(0.08))
                            Toggle(isOn: $game.hapticsOn) { Label("Вибрация", systemImage: "iphone.radiowaves.left.and.right") }
                            Divider().overlay(Color.white.opacity(0.08))
                            Toggle(isOn: $game.highQuality) { Label("Высокая графика", systemImage: "sparkles") }
                        }
                        .font(.game(15, .semibold))
                        .tint(Theme.accent)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))

                        SecondaryButton(title: "Сохранить", icon: "square.and.arrow.down.fill") {
                            game.save()
                            game.showToast("Игра сохранена", icon: "checkmark.circle.fill", tint: Theme.good)
                            dismiss()
                        }
                        SecondaryButton(title: "Новая игра", icon: "arrow.counterclockwise", tint: Theme.bad) {
                            confirmReset = true
                        }
                        Text("Игра сохраняется автоматически")
                            .font(.game(12, .regular)).foregroundColor(.white.opacity(0.4))
                    }
                    .padding(20)
                }
            }
        }
        .foregroundColor(.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Начать заново? Весь прогресс будет потерян.", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Новая игра", role: .destructive) {
                game.newGame()
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}

struct ChartPoint: Identifiable {
    let id: Int
    let value: Double
}

struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).foregroundColor(.white.opacity(0.65))
            Spacer()
            Text(value).fontWeight(.bold).monospacedDigit().foregroundColor(.white)
        }
        .font(.game(14, .medium))
    }
}
