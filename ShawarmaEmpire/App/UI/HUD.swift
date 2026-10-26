import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        ZStack {
            GameSceneView(game: game).ignoresSafeArea()

            if game.showTitle {
                TitleView().transition(.opacity)
            } else if game.scenario != "stats" {
                HUDView().transition(.opacity)
            }

            if game.scenario == "icons" {
                IconSheetQA()
            }

            if let r = game.offline {
                Color.black.opacity(0.5).ignoresSafeArea().transition(.opacity)
                OfflineCard(report: r)
                    .padding(.horizontal, 28)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            Color.black
                .ignoresSafeArea()
                .opacity(game.fade ? 1 : 0)
                .allowsHitTesting(game.fade)
        }
        .sheet(item: $game.sheet) { kind in
            let detents: Set<PresentationDetent> = (kind == .menu || kind == .city) ? [.large] : [.medium, .large]
            Group {
                switch kind {
                case .upgrades: UpgradesSheet()
                case .city: CitySheet()
                case .empire: EmpireSheet()
                case .quests: QuestsSheet()
                case .menu: MenuSheet()
                }
            }
            .environmentObject(game)
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
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
            SecondRow()
            if game.tutorialActive {
                TutorialCard()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            HStack(alignment: .top, spacing: 8) {
                if let d = game.hud.delivery {
                    DeliveryChip(d: d).transition(.scale.combined(with: .opacity))
                }
                Spacer(minLength: 0)
                if game.hud.queue > 0 {
                    QueueChip(count: game.hud.queue)
                }
            }
            if let t = game.toast {
                ToastView(toast: t)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
            Group {
                switch game.selected {
                case .station(let j):
                    StationPanel(j: j)
                        .id("st\(j)")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .locked(let j):
                    LockedPanel(j: j)
                        .id("lock\(j)")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .counter:
                    CounterPanel()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .courier:
                    CourierPanel()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case nil:
                    EmptyView()
                }
            }
            BottomBar()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: game.selected)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: game.hud.delivery == nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: game.tutorialActive)
    }
}

// MARK: - Top

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
                        .foregroundColor(game.hud.boostTime > 0 ? Pal.accent : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .black))
                        Text("\(Fmt.money(game.hud.income)) / мин").font(.game(11, .bold)).monospacedDigit()
                    }
                    .foregroundColor(Pal.good)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .padding(.vertical, 7)
            .glass(26)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.system(size: 12, weight: .black)).foregroundColor(Pal.star)
                Text(String(format: "%.1f", game.hud.rating)).font(.game(15, .heavy)).monospacedDigit()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 11)
            .frame(height: 44)
            .glass(22)

            HStack(spacing: 5) {
                Image(systemName: clockIcon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(clockTint)
                Text(game.hud.clock).font(.game(15, .heavy)).monospacedDigit().foregroundColor(.white)
            }
            .padding(.horizontal, 11)
            .frame(height: 44)
            .glass(22)
        }
    }

    private var clockIcon: String {
        if game.hud.raining { return "cloud.rain.fill" }
        if game.hud.rush { return "flame.fill" }
        return game.hud.night ? "moon.stars.fill" : "sun.max.fill"
    }

    private var clockTint: Color {
        if game.hud.raining { return Pal.info }
        if game.hud.rush { return Color(hex: 0xFF8A50) }
        return game.hud.night ? Color(hex: 0xB39DDB) : Pal.star
    }
}

struct SecondRow: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Sound.shared.play(.tap)
                game.sheet = .city
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: Catalog.locations[game.hud.loc].theme.signColor))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Catalog.locations[game.hud.loc].name)
                            .font(.game(14, .heavy))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("точка \(game.hud.loc + 1) из \(Catalog.locations.count)")
                            .font(.game(10, .semibold))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .heavy)).foregroundColor(.white.opacity(0.5))
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .frame(height: 44)
                .glass(22)
            }
            .buttonStyle(PressableStyle())

            Spacer(minLength: 4)

            RoundButton(icon: "checklist", badge: game.hud.questsReady, tint: Pal.good) {
                Sound.shared.play(.tap)
                game.sheet = .quests
            }
            RoundButton(icon: "crown.fill", dot: game.hud.empireReady, tint: Pal.star) {
                Sound.shared.play(.tap)
                game.sheet = .empire
            }
            RoundButton(icon: "line.3.horizontal") {
                Sound.shared.play(.tap)
                game.sheet = .menu
            }
        }
    }
}

struct TutorialCard: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        let step = game.hud.tutorial
        let texts = GameController.tutorialTexts
        let isCard = step == 0 || step == texts.count - 1
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill").foregroundColor(Pal.accent)
                Text("Обучение · \(min(step + 1, texts.count))/\(texts.count)")
                    .font(.game(12, .heavy))
                    .foregroundColor(Pal.accent)
                Spacer()
                if !isCard {
                    Button("Пропустить") { game.skipTutorial() }
                        .font(.game(12, .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            Text(texts[min(step, texts.count - 1)])
                .font(.game(15, .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .id(step)
            if isCard {
                PrimaryButton(title: step == 0 ? "Поехали!" : "Начать бизнес", icon: step == 0 ? "arrow.right" : "flag.checkered") {
                    game.advanceTutorial()
                }
            }
        }
        .padding(14)
        .glass(18)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Pal.accent.opacity(0.5), lineWidth: 1.5))
    }
}

struct DeliveryChip: View {
    @EnvironmentObject var game: GameController
    let d: DeliveryHUD

    var body: some View {
        Button {
            Sound.shared.play(.tap)
            game.select(.courier)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "scooter")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: 0x81C784))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(d.waiting ? "Доставка \(d.delivered)/\(d.required)" : "Курьер едет…")
                            .font(.game(12, .heavy))
                            .foregroundColor(.white)
                        if d.waiting {
                            Text(Fmt.duration(d.timeLeft)).font(.game(11, .bold)).monospacedDigit()
                                .foregroundColor(d.timeLeft < 20 ? Pal.bad : .white.opacity(0.6))
                        }
                    }
                    ProgressBar(value: d.waiting ? Double(d.delivered) / Double(max(1, d.required)) : 0,
                                tint: Color(hex: 0x81C784))
                        .frame(width: 110, height: 5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glass(16)
        }
        .buttonStyle(PressableStyle())
    }
}

struct QueueChip: View {
    let count: Int
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "person.2.fill").font(.system(size: 11, weight: .bold))
            Text("\(count)").font(.game(13, .heavy)).monospacedDigit()
        }
        .foregroundColor(.white.opacity(0.85))
        .padding(.horizontal, 10)
        .frame(height: 32)
        .glass(16)
    }
}

// MARK: - Bottom bar

struct BottomBar: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Sound.shared.play(.tap)
                game.sheet = .upgrades
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 17, weight: .heavy))
                    Text("Улучшения").font(.game(16, .heavy))
                }
                .foregroundColor(Pal.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0xFFD45E), Color(hex: 0xF59324)], startPoint: .top, endPoint: .bottom))
                )
                .overlay(alignment: .topTrailing) {
                    if game.hud.canUpgrade {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(Pal.good)
                            .background(Circle().fill(Pal.panelBottom).padding(2))
                            .offset(x: 5, y: -6)
                    }
                }
            }
            .buttonStyle(PressableStyle())

            Button {
                Sound.shared.play(.tap)
                game.sheet = .city
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "map.fill").font(.system(size: 18, weight: .bold))
                    Text("Город").font(.game(11, .heavy))
                }
                .foregroundColor(.white)
                .frame(width: 66, height: 54)
                .glass(18)
            }
            .buttonStyle(PressableStyle())

            BoostButton()
        }
    }
}

struct BoostButton: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        let active = game.hud.boostTime > 0
        let cooling = !active && game.hud.boostCooldown > 0
        Button {
            game.activateBoost()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "bolt.fill").font(.system(size: 18, weight: .black))
                Text(active ? Fmt.duration(game.hud.boostTime) : (cooling ? Fmt.duration(game.hud.boostCooldown) : "×2"))
                    .font(.game(11, .heavy))
                    .monospacedDigit()
            }
            .foregroundColor(active ? Pal.ink : (cooling ? .white.opacity(0.45) : Pal.accent))
            .frame(width: 66, height: 54)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(active ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE082), Pal.accent], startPoint: .top, endPoint: .bottom))
                                 : AnyShapeStyle(LinearGradient(colors: [Pal.panelTop.opacity(0.93), Pal.panelBottom.opacity(0.93)],
                                                                startPoint: .top, endPoint: .bottom)))
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cooling ? Pal.stroke : Pal.accent.opacity(0.7), lineWidth: cooling ? 1 : 1.5))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Offline

struct OfflineCard: View {
    @EnvironmentObject var game: GameController
    let report: OfflineReport

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color(hex: 0xB39DDB))
            Text("Пока вас не было").font(.game(22, .heavy)).foregroundColor(.white)
            Text("Повара работали \(Fmt.duration(report.seconds)) и заработали:")
                .font(.game(14, .semibold))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                CoinView(size: 34)
                Text(Fmt.money(report.amount)).font(.game(32, .black)).foregroundColor(Pal.accent).monospacedDigit()
            }
            Text("Ночная смена в «Империи» продлевает время офлайн-дохода")
                .font(.game(11, .semibold))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Забрать", icon: "hand.tap.fill") { game.collectOffline() }
        }
        .padding(22)
        .glass(26)
    }
}

// MARK: - QA

struct IconSheetQA: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        VStack {
            Spacer()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach(Dish.allCases, id: \.self) { d in
                    VStack(spacing: 2) {
                        DishBadge(dish: d, size: 58)
                        Text(d.title).font(.game(9, .bold)).foregroundColor(.white).lineLimit(1)
                    }
                }
            }
            .padding(12)
            .glass(20)
            .padding(.horizontal, 12)
            .padding(.bottom, 120)
        }
    }
}
