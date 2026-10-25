import SwiftUI

enum Theme {
    static let accent = Color(hex: 0xFFC94A)
    static let accentDeep = Color(hex: 0xF59E0B)
    static let good = Color(hex: 0x4ADE80)
    static let bad = Color(hex: 0xF87171)
    static let info = Color(hex: 0x8AB4F8)
    static let panelStroke = Color.white.opacity(0.14)
    static let ink = Color(hex: 0x0E141C)
}

extension Font {
    static func game(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Dark glass panel used throughout the HUD.
struct Glass: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            // Solid translucent fill instead of a live blur: blurring a 3D view that changes
            // every frame costs a lot of GPU time.
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x1A2430).opacity(0.9), Color(hex: 0x0E141C).opacity(0.9)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.panelStroke, lineWidth: 1))
    }
}

extension View {
    func glass(_ radius: CGFloat = 20) -> some View { modifier(Glass(radius: radius)) }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct Icon3D: View {
    @EnvironmentObject var game: GameController
    let key: String
    var size: CGFloat = 28
    var fallback: Color = .gray

    var body: some View {
        Group {
            if let img = game.icons[key] {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Circle().fill(fallback.opacity(0.8)).padding(size * 0.2)
            }
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
    var tint: Color = Theme.accent

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
    var badge: Bool = false
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 46, height: 46)
                .glass(23)
                .overlay(alignment: .topTrailing) {
                    if badge {
                        Circle().fill(Theme.accent)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
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
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(toast.tint)
            Text(toast.text)
                .font(.game(14, .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .glass(18)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(toast.tint.opacity(0.45), lineWidth: 1))
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
                    if let subtitle { Text(subtitle).font(.game(11, .semibold)).opacity(0.75) }
                }
            }
            .foregroundColor(enabled ? Theme.ink : .white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, subtitle == nil ? 13 : 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(enabled ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFD866), Color(hex: 0xF5A524)],
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
    let icon: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title).font(.game(13, .semibold))
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.13)))
        }
        .buttonStyle(PressableStyle())
    }
}
