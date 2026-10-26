import SwiftUI

struct TitleView: View {
    @EnvironmentObject var game: GameController
    @State private var appear = false
    @State private var glow = false
    @State private var confirmNew = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.6), .clear, .clear, Color.black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer().frame(height: 64)
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xF59E0B)],
                                                            startPoint: .top, endPoint: .bottom))
                            .rotationEffect(.degrees(glow ? 8 : -8))
                    }
                    .padding(.bottom, 4)
                    Text("ШАУРМА")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFF3E0), Color(hex: 0xFFCC80)], startPoint: .top, endPoint: .bottom))
                    Text("ИМПЕРИЯ")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .tracking(8)
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFD54F), Color(hex: 0xF57C00)],
                                                        startPoint: .top, endPoint: .bottom))
                        .offset(y: -6)
                    Text("От ларька у метро до флагмана в Сити")
                        .font(.game(15, .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.35)))
                        .padding(.top, 6)
                }
                .shadow(color: .black.opacity(0.55), radius: 12, y: 6)
                .scaleEffect(appear ? 1 : 0.85)
                .opacity(appear ? 1 : 0)

                Spacer()

                VStack(spacing: 12) {
                    Button { game.startPlaying() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill").font(.system(size: 20, weight: .black))
                            Text(game.hasSave ? "Продолжить" : "Открыть ларёк").font(.game(22, .heavy))
                        }
                        .foregroundColor(Pal.ink)
                        .frame(maxWidth: 290)
                        .padding(.vertical, 18)
                        .background(
                            Capsule().fill(LinearGradient(colors: [Color(hex: 0xFFE066), Color(hex: 0xF57C00)],
                                                          startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                        .shadow(color: Color(hex: 0xF57C00).opacity(glow ? 0.85 : 0.35), radius: glow ? 22 : 10)
                    }
                    .buttonStyle(PressableStyle())

                    if game.hasSave {
                        Button("Новая игра") { confirmNew = true }
                            .font(.game(15, .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 30)
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.15)) { appear = true }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
        }
        .confirmationDialog("Начать заново? Сохранение будет удалено.", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("Новая игра", role: .destructive) {
                game.newGame()
                game.startPlaying()
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}
