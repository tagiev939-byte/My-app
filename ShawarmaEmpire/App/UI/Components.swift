import SwiftUI

/// UI palette (warm street-food colors).
enum Pal {
    static let accent = Color(hex: 0xFFB531)
    static let accentDeep = Color(hex: 0xF57C00)
    static let good = Color(hex: 0x66D17A)
    static let bad = Color(hex: 0xFF6B6B)
    static let info = Color(hex: 0x7FD6F0)
    static let star = Color(hex: 0xFFD54F)
    static let stroke = Color.white.opacity(0.14)
    static let ink = Color(hex: 0x2A1606)
    static let panelTop = Color(hex: 0x33221A)
    static let panelBottom = Color(hex: 0x1C130E)
    static let sheet = Color(hex: 0x1A120D)
    static let card = Color.white.opacity(0.06)
}

extension Font {
    static func game(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Dark warm glass panel (solid fill: a live blur over a 3D view is expensive).
struct Glass: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Pal.panelTop.opacity(0.93), Pal.panelBottom.opacity(0.93)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Pal.stroke, lineWidth: 1))
    }
}

extension View {
    func glass(_ radius: CGFloat = 20) -> some View { modifier(Glass(radius: radius)) }

    func card(_ radius: CGFloat = 16) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Pal.card))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct Icon3D: View {
    @EnvironmentObject var game: GameController
    let dish: Dish
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let img = game.icons[dish.iconKey] {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Circle().fill(dish.color.opacity(0.85)).padding(size * 0.2)
            }
        }
        .frame(width: size, height: size)
    }
}

struct DishBadge: View {
    let dish: Dish
    var size: CGFloat = 52
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [dish.color.opacity(0.55), dish.color.opacity(0.12)],
                                         center: .center, startRadius: 2, endRadius: size * 0.6))
            Circle().stroke(dish.color.opacity(0.6), lineWidth: 1.5)
            Icon3D(dish: dish, size: size * 0.92)
        }
        .frame(width: size, height: size)
    }
}

struct CoinView: View {
    var size: CGFloat = 26
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xD99A1E)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().stroke(Color(hex: 0x9A6A10).opacity(0.7), lineWidth: max(1, size * 0.06)).padding(size * 0.12)
            Text("$").font(.system(size: size * 0.55, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: 0x7A4E06))
        }
        .frame(width: size, height: size)
    }
}

struct ProgressBar: View {
    let value: Double
    var tint: Color = Pal.accent

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, value)) * g.size.width)
                    .animation(.easeOut(duration: 0.25), value: value)
            }
        }
    }
}

struct RoundButton: View {
    let icon: String
    var badge: Int = 0
    var dot = false
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .glass(22)
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.game(11, .heavy))
                            .foregroundColor(Pal.ink)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Circle().fill(Pal.good))
                            .overlay(Circle().stroke(Pal.panelBottom, lineWidth: 2))
                            .offset(x: 4, y: -3)
                    } else if dot {
                        Circle().fill(Pal.accent)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(Pal.panelBottom, lineWidth: 2))
                            .offset(x: -1, y: 1)
                    }
                }
        }
        .buttonStyle(PressableStyle())
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: toast.big ? 20 : 16, weight: .bold))
                .foregroundColor(toast.tint)
            Text(toast.text)
                .font(.game(toast.big ? 16 : 14, toast.big ? .heavy : .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, toast.big ? 14 : 11)
        .glass(18)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(toast.tint.opacity(toast.big ? 0.8 : 0.45),
                                                                               lineWidth: toast.big ? 2 : 1))
    }
}

struct PrimaryButton: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var enabled: Bool = true
    var highlight: Bool = false
    let action: () -> Void
    @State private var glow = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .heavy)) }
                VStack(spacing: 1) {
                    Text(title).font(.game(15, .heavy))
                    if let subtitle { Text(subtitle).font(.game(12, .bold)).opacity(0.8).monospacedDigit() }
                }
            }
            .foregroundColor(enabled ? Pal.ink : .white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, subtitle == nil ? 13 : 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(enabled ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFD45E), Color(hex: 0xF59324)],
                                                                 startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(Color.white.opacity(0.1)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(highlight && glow ? 0.95 : 0), lineWidth: 3)
            )
        }
        .buttonStyle(PressableStyle())
        .onAppear {
            if highlight {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { glow = true }
            }
        }
    }
}

struct SecondaryButton: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    var tint: Color = .white
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 14, weight: .bold))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.game(13, .bold))
                    if let subtitle { Text(subtitle).font(.game(11, .semibold)).opacity(0.75).monospacedDigit() }
                }
            }
            .foregroundColor(enabled ? tint : .white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, subtitle == nil ? 11 : 7)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill((enabled ? tint : .white).opacity(0.13)))
        }
        .buttonStyle(PressableStyle())
    }
}

struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    var tint: Color = .white

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
                Text(title).font(.game(10, .semibold))
            }
            .foregroundColor(.white.opacity(0.55))
            Text(value)
                .font(.game(14, .heavy))
                .foregroundColor(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .card(12)
    }
}

struct BulkPicker: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        HStack(spacing: 4) {
            ForEach(BulkMode.allCases, id: \.self) { m in
                Button {
                    game.bulk = m
                    Sound.shared.play(.tap, volume: 0.5)
                    Haptics.soft(0.3)
                } label: {
                    Text(m.title)
                        .font(.game(12, .heavy))
                        .foregroundColor(game.bulk == m ? Pal.ink : .white.opacity(0.7))
                        .frame(width: 44, height: 26)
                        .background(Capsule().fill(game.bulk == m ? Pal.accent : Color.white.opacity(0.08)))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

struct SheetHeader: View {
    let title: String
    let icon: String
    var tint: Color = Pal.accent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.15)))
            Text(title).font(.game(22, .heavy)).foregroundColor(.white)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }
}

struct MoneyText: View {
    let value: Double
    var size: CGFloat = 13
    var affordable = true
    var body: some View {
        HStack(spacing: 4) {
            CoinView(size: size + 3)
            Text(Fmt.money(value))
                .font(.game(size, .heavy))
                .monospacedDigit()
                .foregroundColor(affordable ? .white : Pal.bad)
        }
    }
}
