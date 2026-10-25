import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        ZStack {
            GameSceneView(game: game).ignoresSafeArea()

            if game.showTitle {
                TitleView().transition(.opacity)
            } else {
                HUDView().transition(.opacity)
            }

            if game.scenario == "icons" {
                IconSheetQA()
            }

            if let r = game.offline {
                Color.black.opacity(0.45).ignoresSafeArea().transition(.opacity)
                OfflineCard(report: r)
                    .padding(.horizontal, 28)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .sheet(item: $game.sheet) { kind in
            Group {
                switch kind {
                case .goals: GoalsSheet()
                case .upgrades: UpgradesSheet()
                case .menu: MenuSheet()
                }
            }
            .environmentObject(game)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(game.showTitle)
    }
}

struct HUDView: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        VStack(spacing: 8) {
            TopBar()
            if game.tutorialActive {
                TutorialCard()
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                GoalBanner()
            }
            HStack(alignment: .top, spacing: 8) {
                if let c = game.hud.contract {
                    ContractChip(contract: c).transition(.scale.combined(with: .opacity))
                }
                Spacer(minLength: 0)
                if game.world.goalIndex >= 2 { BoostButton() }
            }
            if let t = game.toast {
                ToastView(toast: t)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
            Group {
                if let p = game.selected, let b = game.world.building(p.x, p.y) {
                    InspectorPanel(building: b, pos: p)
                        .id("\(p.x):\(p.y)")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let c = game.selectedChunk {
                    LandPanel(chunk: c)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            ToolbarView()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: game.selected)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: game.selectedChunk)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: game.hud.contract == nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: game.tutorialActive)
    }
}

// MARK: - Top bar

struct TopBar: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                CoinView(size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Fmt.money(game.hud.money))
                        .font(.game(21, .heavy))
                        .monospacedDigit()
                        .foregroundColor(game.hud.boostTime > 0 ? Theme.accent : .white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: game.hud.money)
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .black))
                        Text("\(Fmt.money(game.hud.income)) / мин").font(.game(11, .bold)).monospacedDigit()
                    }
                    .foregroundColor(Theme.good)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 16)
            .padding(.vertical, 7)
            .glass(26)

            Spacer(minLength: 4)

            RoundButton(icon: "bolt.circle.fill", badge: game.hud.canBuyUpgrade, tint: Theme.accent) {
                Sound.shared.play(.tap)
                game.sheet = .upgrades
            }
            RoundButton(icon: "flag.checkered") {
                Sound.shared.play(.tap)
                game.sheet = .goals
            }
            RoundButton(icon: "line.3.horizontal") {
                Sound.shared.play(.tap)
                game.sheet = .menu
            }
        }
    }
}

struct GoalBanner: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        Button {
            Sound.shared.play(.tap)
            game.sheet = .goals
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.16))
                    if let g = game.world.currentGoal {
                        if let key = g.iconKey {
                            Icon3D(key: key, size: 30)
                        } else {
                            Image(systemName: g.symbol).font(.system(size: 15, weight: .heavy)).foregroundColor(Theme.accent)
                        }
                    } else {
                        Image(systemName: "crown.fill").font(.system(size: 15, weight: .heavy)).foregroundColor(Theme.accent)
                    }
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 5) {
                    if let g = game.world.currentGoal {
                        HStack(spacing: 6) {
                            Text(g.title).font(.game(14, .bold)).foregroundColor(.white).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(Fmt.gain(g.reward)).font(.game(12, .heavy)).foregroundColor(Theme.accent)
                        }
                        ProgressBar(value: game.hud.goalProgress).frame(height: 6)
                    } else {
                        Text("Империя построена! Все цели выполнены").font(.game(14, .bold)).foregroundColor(.white)
                    }
                }
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .glass(18)
        }
        .buttonStyle(PressableStyle())
    }
}

struct TutorialCard: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        let step = game.hud.tutorialStep
        let texts = GameController.tutorialTexts
        let isCard = step == 0 || step == texts.count - 1
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill").foregroundColor(Theme.accent)
                Text("Обучение · \(min(step + 1, texts.count))/\(texts.count)")
                    .font(.game(12, .heavy))
                    .foregroundColor(Theme.accent)
                Spacer()
                Button("Пропустить") { game.skipTutorial() }
                    .font(.game(12, .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            Text(texts[min(step, texts.count - 1)])
                .font(.game(15, .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .id(step)
                .transition(.opacity)
            if isCard {
                PrimaryButton(title: step == 0 ? "Поехали!" : "Понятно", icon: step == 0 ? "play.fill" : "checkmark") {
                    game.advanceTutorial()
                }
            }
        }
        .padding(14)
        .glass(20)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.accent.opacity(0.5), lineWidth: 1.5))
        .animation(.easeInOut(duration: 0.25), value: step)
    }
}

struct ContractChip: View {
    @EnvironmentObject var game: GameController
    let contract: Contract

    var body: some View {
        HStack(spacing: 8) {
            Icon3D(key: contract.item.iconKey, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("Контракт").font(.game(11, .heavy)).foregroundColor(Theme.info)
                    Text(Fmt.duration(contract.timeLeft))
                        .font(.game(11, .bold)).monospacedDigit()
                        .foregroundColor(contract.timeLeft < 60 ? Theme.bad : .white.opacity(0.7))
                }
                Text("\(contract.delivered)/\(contract.amount) · \(Fmt.gain(contract.reward))")
                    .font(.game(12, .bold)).monospacedDigit()
                    .foregroundColor(.white)
                ProgressBar(value: Double(contract.delivered) / Double(max(1, contract.amount)), tint: Theme.info)
                    .frame(width: 110, height: 4)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .glass(16)
    }
}

struct BoostButton: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        let active = game.hud.boostTime > 0
        let cooldown = game.hud.boostCooldown
        let ready = !active && cooldown <= 0
        Button { game.activateBoost() } label: {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").font(.system(size: 14, weight: .black))
                if active {
                    Text("×2 · \(Fmt.duration(game.hud.boostTime))").font(.game(13, .heavy)).monospacedDigit()
                } else if ready {
                    Text("×2").font(.game(14, .heavy))
                } else {
                    Text(Fmt.duration(cooldown)).font(.game(12, .bold)).monospacedDigit()
                }
            }
            .foregroundColor(ready || active ? Theme.ink : .white.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(ready || active
                               ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE066), Color(hex: 0xF59E0B)],
                                                              startPoint: .top, endPoint: .bottom))
                               : AnyShapeStyle(Color(hex: 0x0F1620).opacity(0.7)))
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Toolbar

struct ToolbarView: View {
    @EnvironmentObject var game: GameController

    var hintText: String? {
        switch game.tool {
        case .build(let t): return t.info
        case .demolish: return "Нажмите или проведите по постройкам, чтобы снести. Возврат 50%."
        case .inspect: return nil
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            if let hintText {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill").font(.system(size: 11, weight: .bold))
                    Text(hintText).font(.game(11, .medium)).lineLimit(2)
                    Spacer(minLength: 0)
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glass(12)
                .transition(.opacity)
            }

            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ToolButton(title: "Осмотр", selected: game.tool == .inspect, locked: false,
                                   highlight: game.tutorialTool == .inspect) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        } action: { game.selectTool(.inspect) }

                        ForEach(BuildingType.allCases, id: \.self) { type in
                            ToolButton(title: type.title, price: Fmt.money(type.cost),
                                       selected: game.tool == .build(type),
                                       locked: !game.isUnlocked(type),
                                       highlight: game.tutorialTool == .build(type)) {
                                Icon3D(key: type.iconKey, size: 42)
                            } action: { game.selectTool(.build(type)) }
                        }

                        ToolButton(title: "Снос", selected: game.tool == .demolish, locked: false, highlight: false) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(Theme.bad)
                        } action: { game.selectTool(.demolish) }
                    }
                    .padding(.horizontal, 6)
                }

                Button { game.rotateTool() } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 22, weight: .black))
                            .rotationEffect(.degrees(Double(game.rotation.rawValue) * 90))
                            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: game.rotation)
                            .frame(width: 36, height: 36)
                        Text("Поворот").font(.game(10, .bold))
                    }
                    .foregroundColor(Theme.ink)
                    .frame(width: 64, height: 72)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: 0xFFD866), Color(hex: 0xF5A524)], startPoint: .top, endPoint: .bottom))
                    )
                }
                .buttonStyle(PressableStyle())
                .padding(.trailing, 6)
            }
            .padding(.vertical, 6)
            .glass(24)
        }
        .animation(.easeInOut(duration: 0.2), value: game.tool)
    }
}

struct ToolButton<Icon: View>: View {
    let title: String
    var price: String? = nil
    let selected: Bool
    let locked: Bool
    let highlight: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                ZStack {
                    icon()
                    if locked {
                        RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.55)).frame(width: 40, height: 40)
                        Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.85))
                    }
                }
                .frame(width: 44, height: 42)
                Text(title)
                    .font(.game(10, .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let price {
                    Text(price).font(.game(9, .heavy)).foregroundColor(Theme.accent)
                }
            }
            .frame(width: 66, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(selected ? Theme.accent.opacity(0.24) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(selected ? Theme.accent : Color.clear, lineWidth: 2)
            )
            .overlay {
                if highlight && !selected { BlinkBorder(radius: 15) }
            }
            .opacity(locked ? 0.6 : 1)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Pulsing outline used by the tutorial; only exists while it is needed.
struct BlinkBorder: View {
    let radius: CGFloat
    @State private var on = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(Color.white.opacity(on ? 1 : 0.2), lineWidth: 3)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

/// QA view listing every rendered 3D icon (launch argument -scenario icons).
struct IconSheetQA: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        let keys = BuildingType.allCases.map { $0.iconKey } + ItemType.allCases.map { $0.iconKey }
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(keys, id: \.self) { k in
                    VStack(spacing: 2) {
                        Icon3D(key: k, size: 64)
                        Text(k.replacingOccurrences(of: "item.", with: "").replacingOccurrences(of: "building.", with: ""))
                            .font(.game(9, .semibold)).foregroundColor(.white)
                    }
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                }
            }
            .padding(.top, 60)
            .padding(.horizontal, 12)
        }
        .background(Color(hex: 0x1A2533).ignoresSafeArea())
    }
}
