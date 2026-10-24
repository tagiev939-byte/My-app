import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            GameBoardView().ignoresSafeArea()

            VStack(spacing: 8) {
                TopBar()
                GoalBanner()
                if let t = store.toast {
                    ToastView(toast: t)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
                if let p = store.selected, let b = store.world.building(p.x, p.y) {
                    InspectorPanel(building: b, pos: p)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                ToolbarView()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.toast)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.selected)
        }
        .sheet(item: $store.sheet) { kind in
            switch kind {
            case .goals: GoalsSheet()
            case .upgrades: UpgradesSheet()
            case .menu: MenuSheet()
            case .help: HelpSheet()
            }
        }
    }
}

// MARK: - Top bar

struct CoinView: View {
    var size: CGFloat = 26
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xD99A1E)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().stroke(Color(hex: 0x9A6A10).opacity(0.7), lineWidth: 1.5).padding(3)
            Text("$").font(.system(size: size * 0.55, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: 0x7A4E06))
        }
        .frame(width: size, height: size)
    }
}

struct RoundButton: View {
    let icon: String
    var badge: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    if badge {
                        Circle().fill(Theme.accent).frame(width: 10, height: 10).offset(x: -2, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct TopBar: View {
    @EnvironmentObject var store: GameStore

    var canAffordUpgrade: Bool {
        UpgradeType.allCases.contains { u in
            let l = store.world.level(u)
            return l < u.maxLevel && store.money >= u.cost(level: l)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                CoinView()
                VStack(alignment: .leading, spacing: 0) {
                    Text(Fmt.money(store.money))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                    Text("\(Fmt.money(store.income)) / мин")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.good.opacity(0.9))
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))

            Spacer()

            RoundButton(icon: "bolt.fill", badge: canAffordUpgrade) { store.sheet = .upgrades }
            RoundButton(icon: "flag.checkered") { store.sheet = .goals }
            RoundButton(icon: "line.3.horizontal") { store.sheet = .menu }
        }
    }
}

struct GoalBanner: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        Button { store.sheet = .goals } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.18))
                    if let g = store.world.currentGoal, let icon = g.icon {
                        ItemIcon(item: icon, size: 22)
                    } else {
                        Image(systemName: store.world.currentGoal == nil ? "crown.fill" : "dollarsign")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.accent)
                    }
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    if let g = store.world.currentGoal {
                        HStack {
                            Text("Цель \(store.goalIndex + 1)/\(Goal.all.count): \(g.title)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                            Text(Fmt.gain(g.reward))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.accent)
                        }
                        ProgressBar(value: store.goalProgress, tint: Theme.accent)
                            .frame(height: 6)
                    } else {
                        Text("Империя построена! Все цели выполнены")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ProgressBar: View {
    let value: Double
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, value)) * g.size.width)
            }
        }
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.icon).foregroundColor(toast.tint)
            Text(toast.text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(toast.tint.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

// MARK: - Toolbar

struct ToolbarView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        VStack(spacing: 6) {
            if case .build(let t) = store.tool {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").font(.system(size: 11, weight: .bold))
                    Text(t.info).font(.system(size: 11, weight: .medium, design: .rounded))
                    Spacer(minLength: 0)
                }
                .foregroundColor(.white.opacity(0.75))
                .padding(.horizontal, 6)
            } else if store.tool == .demolish {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").font(.system(size: 11, weight: .bold))
                    Text("Нажмите или проведите по постройкам, чтобы снести. Возврат 60%.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                    Spacer(minLength: 0)
                }
                .foregroundColor(.white.opacity(0.75))
                .padding(.horizontal, 6)
            }

            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ToolButton(title: "Осмотр", selected: store.tool == .inspect, locked: false) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                        } action: { store.selectTool(.inspect) }

                        ForEach(BuildingType.allCases, id: \.self) { type in
                            ToolButton(title: type.title, price: Fmt.money(type.cost),
                                       selected: store.tool == .build(type),
                                       locked: !store.isUnlocked(type)) {
                                BuildingIcon(type: type, dir: type.hasDirection ? store.rotation : .up, size: 34)
                            } action: { store.selectTool(.build(type)) }
                        }

                        ToolButton(title: "Снос", selected: store.tool == .demolish, locked: false) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Theme.bad)
                                .frame(width: 34, height: 34)
                        } action: { store.selectTool(.demolish) }
                    }
                    .padding(.horizontal, 6)
                }

                Button { store.rotateTool() } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .heavy))
                            .rotationEffect(.radians(store.rotation.radians))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.rotation)
                            .frame(width: 34, height: 34)
                        Text("Поворот").font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(width: 62, height: 66)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
            }
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

struct ToolButton<Icon: View>: View {
    let title: String
    var price: String? = nil
    let selected: Bool
    let locked: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    icon()
                    if locked {
                        RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.55)).frame(width: 34, height: 34)
                        Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.8))
                    }
                }
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let price {
                    Text(price)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.accent)
                }
            }
            .frame(width: 64, height: 66)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Theme.accent.opacity(0.22) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Theme.accent : Color.clear, lineWidth: 2)
            )
            .opacity(locked ? 0.6 : 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inspector

struct InspectorPanel: View {
    @EnvironmentObject var store: GameStore
    let building: Building
    let pos: TilePos

    var body: some View {
        let b = building
        let status = store.world.status(of: b)
        let _ = store.refresh

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                BuildingIcon(type: b.type, dir: b.dir, recipeOutput: b.recipe?.output, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(b.type.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    HStack(spacing: 5) {
                        Circle().fill(status.ok ? Theme.good : Color.orange).frame(width: 7, height: 7)
                        Text(status.text)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                Spacer()
                Button { store.selected = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if b.type.isMachine {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Recipe.list(for: b.type)) { r in
                            Button { store.setRecipe(r.id, at: pos) } label: {
                                HStack(spacing: 4) {
                                    ItemIcon(item: r.output, size: 20)
                                    Text(r.output.title)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(r.id == b.recipeId ? Theme.accent.opacity(0.25) : Color.white.opacity(0.07))
                                )
                                .overlay(Capsule().stroke(r.id == b.recipeId ? Theme.accent : Color.clear, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let r = b.recipe {
                    HStack(spacing: 8) {
                        ForEach(r.inputs, id: \.item) { ing in
                            HStack(spacing: 3) {
                                ItemIcon(item: ing.item, size: 22)
                                Text("\(b.count(ing.item))/\(ing.count)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(b.count(ing.item) >= ing.count ? Theme.good : .white.opacity(0.7))
                            }
                        }
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                        ItemIcon(item: r.output, size: 22)
                        Text("×\(r.outputCount)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.1f с", r.time / store.world.machineMult))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    ProgressBar(value: b.progress, tint: Theme.accent).frame(height: 6)
                    Text("Сырьё подаётся с любой стороны, кроме выхода (белая стрелка).")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
            } else if b.type == .miner {
                let res = store.world.resource(b.x, b.y)
                HStack(spacing: 8) {
                    if let ore = res.ore { ItemIcon(item: ore, size: 22) }
                    Text(res.ore.map { "Добывает: \($0.title.lowercased())" } ?? "Под буром нет руды")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text(String(format: "%.0f / мин", 60 / World.minerTime * store.world.minerMult))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                ProgressBar(value: b.progress, tint: Theme.accent).frame(height: 6)
            } else {
                Text(b.type.info)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                if b.type == .seller {
                    Text(String(format: "Множитель цен: ×%.2f", store.world.priceMult))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.accent)
                }
            }

            HStack(spacing: 8) {
                if b.type.hasDirection {
                    Button { store.rotate(pos) } label: {
                        Label("Повернуть", systemImage: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }
                Button { store.demolish(pos) } label: {
                    Label("Снести  +\(Fmt.money((b.type.cost * 0.6).rounded()))", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.bad.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.bad)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
