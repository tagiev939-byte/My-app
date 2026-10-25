import SwiftUI

// MARK: - Inspector

struct InspectorPanel: View {
    @EnvironmentObject var game: GameController
    let building: Building
    let pos: TilePos

    var body: some View {
        let b = building
        let w = game.world
        let status = w.status(of: b)
        let _ = game.tick

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Icon3D(key: b.type.iconKey, size: 54)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(b.type.title).font(.game(18, .heavy)).foregroundColor(.white)
                        if b.type.isUpgradable {
                            Text("УР. \(b.level)")
                                .font(.game(11, .black))
                                .foregroundColor(Theme.ink)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.accent))
                        }
                    }
                    HStack(spacing: 5) {
                        Circle().fill(status.ok ? Theme.good : Color.orange).frame(width: 7, height: 7)
                        Text(status.text).font(.game(12, .medium)).foregroundColor(.white.opacity(0.75)).lineLimit(1)
                    }
                }
                Spacer()
                Button {
                    game.select(nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(PressableStyle())
            }

            if b.type.isMachine {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Recipe.list(for: b.type)) { r in
                            Button { game.setRecipe(r.id, at: pos) } label: {
                                HStack(spacing: 4) {
                                    Icon3D(key: r.output.iconKey, size: 24)
                                    Text(r.output.title).font(.game(12, .semibold)).foregroundColor(.white)
                                }
                                .padding(.leading, 6)
                                .padding(.trailing, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(r.id == b.recipeId ? Theme.accent.opacity(0.25) : Color.white.opacity(0.07)))
                                .overlay(Capsule().stroke(r.id == b.recipeId ? Theme.accent : Color.clear, lineWidth: 1.5))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }

                if let r = b.recipe {
                    HStack(spacing: 8) {
                        ForEach(r.inputs, id: \.item) { ing in
                            HStack(spacing: 2) {
                                Icon3D(key: ing.item.iconKey, size: 26)
                                Text("\(b.count(ing.item))/\(ing.count)")
                                    .font(.game(12, .heavy)).monospacedDigit()
                                    .foregroundColor(b.count(ing.item) >= ing.count ? Theme.good : .white.opacity(0.7))
                            }
                        }
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .heavy)).foregroundColor(.white.opacity(0.45))
                        Icon3D(key: r.output.iconKey, size: 26)
                        Text("×\(r.outputCount)").font(.game(12, .heavy)).foregroundColor(.white)
                        Spacer(minLength: 0)
                        Text(Fmt.money(r.output.value * Double(r.outputCount)))
                            .font(.game(12, .heavy)).foregroundColor(Theme.accent)
                    }
                    ProgressBar(value: b.progress).frame(height: 6)
                }
            } else if b.type == .drill {
                let res = w.resource(b.x, b.y)
                HStack(spacing: 8) {
                    if let ore = res.ore { Icon3D(key: ore.iconKey, size: 26) }
                    Text(res.ore.map { $0.title } ?? "Под буром нет руды")
                        .font(.game(13, .semibold)).foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
                ProgressBar(value: b.progress).frame(height: 6)
            } else if b.type == .market {
                Text("Продаёт всё, что приезжает. Цены выше на \(Int((marketMultiplier(b.level) * w.priceMult - 1) * 100 + 0.5))%.")
                    .font(.game(13, .medium)).foregroundColor(.white.opacity(0.8))
            } else {
                Text(b.type.info).font(.game(13, .medium)).foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if b.type.isUpgradable {
                if b.level < BuildingType.maxLevel {
                    let cost = b.type.upgradeCost(level: b.level)
                    let detail: String = {
                        if b.type == .market {
                            return String(format: "Цены: +%d%% → +%d%%",
                                          Int((marketMultiplier(b.level) - 1) * 100 + 0.5),
                                          Int((marketMultiplier(b.level + 1) - 1) * 100 + 0.5))
                        }
                        let now = w.ratePerMinute(b)
                        let next = now / levelMultiplier(b.level) * levelMultiplier(b.level + 1)
                        return String(format: "%.0f → %.0f в минуту", now, next)
                    }()
                    PrimaryButton(title: "Улучшить до ур. \(b.level + 1) · \(Fmt.money(cost))",
                                  subtitle: detail,
                                  icon: "arrow.up.circle.fill",
                                  enabled: game.hud.money >= cost,
                                  highlight: game.hud.tutorialStep == 6) {
                        game.upgrade(pos)
                    }
                } else {
                    Text("Максимальный уровень")
                        .font(.game(13, .bold)).foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.12)))
                }
            }

            HStack(spacing: 8) {
                if b.type.hasDirection {
                    SecondaryButton(title: "Повернуть", icon: "arrow.clockwise") { game.rotateBuilding(pos) }
                }
                SecondaryButton(title: "Снести +\(Fmt.money((b.invested * 0.5).rounded()))", icon: "hammer.fill", tint: Theme.bad) {
                    game.demolish(pos)
                }
            }
        }
        .padding(14)
        .glass(24)
    }
}

// MARK: - Land

struct LandPanel: View {
    @EnvironmentObject var game: GameController
    let chunk: Int

    var body: some View {
        let res = game.world.chunkResources(chunk)
        let cost = game.world.landCost
        let order: [Resource] = [.iron, .copper, .stone, .coal, .gold, .quartz]
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill").foregroundColor(Theme.good)
                Text("Участок на продажу").font(.game(18, .heavy)).foregroundColor(.white)
                Spacer()
                Button { game.selectedChunk = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(PressableStyle())
            }
            if res.isEmpty {
                Text("Свободная земля для застройки").font(.game(13, .medium)).foregroundColor(.white.opacity(0.75))
            } else {
                Text("Залежи на участке:").font(.game(13, .medium)).foregroundColor(.white.opacity(0.75))
                HStack(spacing: 10) {
                    ForEach(order.filter { res[$0] != nil }, id: \.self) { r in
                        VStack(spacing: 2) {
                            if let ore = r.ore { Icon3D(key: ore.iconKey, size: 34) }
                            Text(r.title).font(.game(11, .bold)).foregroundColor(.white)
                            Text("\(res[r] ?? 0) кл.").font(.game(10, .semibold)).foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    }
                }
            }
            PrimaryButton(title: "Купить за \(Fmt.money(cost))", icon: "cart.fill", enabled: game.hud.money >= cost) {
                game.buyChunk(chunk)
            }
        }
        .padding(14)
        .glass(24)
    }
}

// MARK: - Offline earnings

struct OfflineCard: View {
    @EnvironmentObject var game: GameController
    let report: OfflineReport
    @State private var shine = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.18)).frame(width: 96, height: 96)
                    .scaleEffect(shine ? 1.1 : 0.95)
                CoinView(size: 64)
            }
            Text("С возвращением!").font(.game(24, .heavy)).foregroundColor(.white)
            Text("Пока вас не было (\(Fmt.duration(report.seconds))), фабрика заработала")
                .font(.game(14, .medium)).foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Text(Fmt.gain(report.amount)).font(.game(34, .black)).foregroundColor(Theme.accent)
            PrimaryButton(title: "Забрать", icon: "hand.raised.fill") { game.collectOffline() }
        }
        .padding(22)
        .glass(28)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { shine = true }
        }
    }
}
