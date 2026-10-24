import SwiftUI

enum Theme {
    static let background = Color(hex: 0x0C1118)
    static let ground = Color(hex: 0x18202B)
    static let groundAlt = Color(hex: 0x1B2430)
    static let border = Color(hex: 0x3A4659)
    static let accent = Color(hex: 0xFFC94A)
    static let good = Color(hex: 0x4ADE80)
    static let bad = Color(hex: 0xF87171)
    static let panel = Color(hex: 0x141B25)
}

enum Art {

    // MARK: Paths

    static func gearPath(center: CGPoint, radius: CGFloat, teeth: Int, rotation: Double, hole: CGFloat = 0.35) -> Path {
        var p = Path()
        let n = teeth * 4
        let inner = radius * 0.78
        for i in 0..<n {
            let a = rotation + Double(i) / Double(n) * 2 * Double.pi
            let r = (i % 4 < 2) ? radius : inner
            let pt = CGPoint(x: center.x + CGFloat(cos(a)) * r, y: center.y + CGFloat(sin(a)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        if hole > 0 {
            let hr = radius * hole
            p.addEllipse(in: CGRect(x: center.x - hr, y: center.y - hr, width: hr * 2, height: hr * 2))
        }
        return p
    }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    // MARK: Items

    static func drawItem(_ ctx: GraphicsContext, _ item: ItemType, at p: CGPoint, size s: CGFloat) {
        let r = s / 2
        let outline = Color.black.opacity(0.6)
        let lw = max(0.8, s * 0.09)
        let color = item.color

        switch item.shape {
        case .ore:
            var path = Path()
            let pts = 8
            for i in 0..<pts {
                let a = Double(i) / Double(pts) * 2 * Double.pi + 0.3
                let rr = r * (i % 2 == 0 ? 0.98 : 0.76)
                let pt = CGPoint(x: p.x + CGFloat(cos(a)) * rr, y: p.y + CGFloat(sin(a)) * rr)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(color))
            ctx.stroke(path, with: .color(item == .coal ? Color.white.opacity(0.35) : outline), lineWidth: lw)
            let hr = r * 0.22
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.42, y: p.y - r * 0.45, width: hr * 2, height: hr * 2)),
                     with: .color(.white.opacity(0.35)))

        case .plate:
            let rect = CGRect(x: p.x - r * 0.92, y: p.y - r * 0.68, width: r * 1.84, height: r * 1.36)
            let path = Path(roundedRect: rect, cornerRadius: s * 0.14)
            ctx.fill(path, with: .linearGradient(Gradient(colors: [color, color.opacity(0.75)]),
                                                 startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                                 endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
            ctx.stroke(path, with: .color(outline), lineWidth: lw)
            var shine = Path()
            shine.move(to: CGPoint(x: rect.minX + r * 0.35, y: rect.minY + r * 0.35))
            shine.addLine(to: CGPoint(x: rect.maxX - r * 0.55, y: rect.minY + r * 0.35))
            ctx.stroke(shine, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: lw, lineCap: .round))

        case .brick:
            let rect = CGRect(x: p.x - r * 0.95, y: p.y - r * 0.6, width: r * 1.9, height: r * 1.2)
            let path = Path(roundedRect: rect, cornerRadius: s * 0.08)
            ctx.fill(path, with: .color(color))
            ctx.stroke(path, with: .color(outline), lineWidth: lw)
            var mortar = Path()
            mortar.move(to: CGPoint(x: rect.minX, y: p.y))
            mortar.addLine(to: CGPoint(x: rect.maxX, y: p.y))
            mortar.move(to: CGPoint(x: p.x, y: rect.minY))
            mortar.addLine(to: CGPoint(x: p.x, y: p.y))
            mortar.move(to: CGPoint(x: p.x - r * 0.45, y: p.y))
            mortar.addLine(to: CGPoint(x: p.x - r * 0.45, y: rect.maxY))
            mortar.move(to: CGPoint(x: p.x + r * 0.45, y: p.y))
            mortar.addLine(to: CGPoint(x: p.x + r * 0.45, y: rect.maxY))
            ctx.stroke(mortar, with: .color(Color(hex: 0xE9D7C4).opacity(0.7)), lineWidth: lw * 0.7)

        case .ingot:
            var path = Path()
            path.move(to: CGPoint(x: p.x - r * 0.62, y: p.y - r * 0.5))
            path.addLine(to: CGPoint(x: p.x + r * 0.62, y: p.y - r * 0.5))
            path.addLine(to: CGPoint(x: p.x + r * 0.98, y: p.y + r * 0.55))
            path.addLine(to: CGPoint(x: p.x - r * 0.98, y: p.y + r * 0.55))
            path.closeSubpath()
            ctx.fill(path, with: .linearGradient(Gradient(colors: [Color(hex: 0xC8D3E0), color, Color(hex: 0x5D6B7D)]),
                                                 startPoint: CGPoint(x: p.x, y: p.y - r),
                                                 endPoint: CGPoint(x: p.x, y: p.y + r)))
            ctx.stroke(path, with: .color(outline), lineWidth: lw)

        case .gear:
            let path = gearPath(center: p, radius: r * 0.98, teeth: 7, rotation: 0, hole: 0.32)
            ctx.fill(path, with: .color(color), style: FillStyle(eoFill: true))
            ctx.stroke(path, with: .color(outline), lineWidth: lw * 0.8)

        case .coil:
            let outer = CGRect(x: p.x - r * 0.9, y: p.y - r * 0.9, width: r * 1.8, height: r * 1.8)
            ctx.fill(Path(ellipseIn: outer), with: .color(outline))
            ctx.stroke(Path(ellipseIn: outer.insetBy(dx: r * 0.2, dy: r * 0.2)), with: .color(color), lineWidth: r * 0.32)
            ctx.stroke(Path(ellipseIn: outer.insetBy(dx: r * 0.55, dy: r * 0.55)), with: .color(color.opacity(0.7)), lineWidth: r * 0.14)

        case .chip:
            let rect = CGRect(x: p.x - r * 0.72, y: p.y - r * 0.72, width: r * 1.44, height: r * 1.44)
            var pins = Path()
            for k in 0..<3 {
                let o = -r * 0.42 + CGFloat(k) * r * 0.42
                pins.move(to: CGPoint(x: rect.minX - r * 0.22, y: p.y + o))
                pins.addLine(to: CGPoint(x: rect.maxX + r * 0.22, y: p.y + o))
                pins.move(to: CGPoint(x: p.x + o, y: rect.minY - r * 0.22))
                pins.addLine(to: CGPoint(x: p.x + o, y: rect.maxY + r * 0.22))
            }
            ctx.stroke(pins, with: .color(Color(hex: 0xF2D27A)), lineWidth: lw * 0.9)
            let body = Path(roundedRect: rect, cornerRadius: s * 0.08)
            ctx.fill(body, with: .color(color))
            ctx.stroke(body, with: .color(outline), lineWidth: lw)
            let core = rect.insetBy(dx: r * 0.4, dy: r * 0.4)
            ctx.fill(Path(roundedRect: core, cornerRadius: s * 0.04), with: .color(Color(hex: 0x10301F)))

        case .motor:
            let outer = CGRect(x: p.x - r * 0.95, y: p.y - r * 0.95, width: r * 1.9, height: r * 1.9)
            ctx.fill(Path(ellipseIn: outer), with: .radialGradient(Gradient(colors: [color.opacity(0.9), Color(hex: 0x234A7A)]),
                                                                  center: CGPoint(x: p.x - r * 0.3, y: p.y - r * 0.3),
                                                                  startRadius: 0, endRadius: r * 1.4))
            ctx.stroke(Path(ellipseIn: outer), with: .color(outline), lineWidth: lw)
            let ring = outer.insetBy(dx: r * 0.45, dy: r * 0.45)
            ctx.fill(Path(ellipseIn: ring), with: .color(Color(hex: 0x14243A)))
            let shaft = outer.insetBy(dx: r * 0.75, dy: r * 0.75)
            ctx.fill(Path(ellipseIn: shaft), with: .color(Color(hex: 0xD3DEE7)))

        case .frame:
            let rect = CGRect(x: p.x - r * 0.82, y: p.y - r * 0.82, width: r * 1.64, height: r * 1.64)
            ctx.fill(Path(roundedRect: rect, cornerRadius: s * 0.08), with: .color(outline))
            ctx.stroke(Path(roundedRect: rect.insetBy(dx: r * 0.16, dy: r * 0.16), cornerRadius: s * 0.05),
                       with: .color(color), lineWidth: r * 0.3)
            var cross = Path()
            cross.move(to: CGPoint(x: rect.minX + r * 0.3, y: rect.minY + r * 0.3))
            cross.addLine(to: CGPoint(x: rect.maxX - r * 0.3, y: rect.maxY - r * 0.3))
            ctx.stroke(cross, with: .color(color.opacity(0.8)), lineWidth: r * 0.18)
        }
    }

    // MARK: Belt

    static func drawBelt(_ ctx: GraphicsContext, rect: CGRect, dir: Dir, phase: Double) {
        var c = ctx
        c.translateBy(x: rect.midX, y: rect.midY)
        c.rotate(by: .radians(dir.radians))
        let h = rect.width / 2
        let local = CGRect(x: -h, y: -h, width: h * 2, height: h * 2)

        c.fill(Path(local.insetBy(dx: h * 0.08, dy: 0)), with: .color(Color(hex: 0x2A313D)))
        let railW = h * 0.2
        c.fill(Path(CGRect(x: -h * 0.92, y: -h, width: railW, height: h * 2)), with: .color(Color(hex: 0x5A6474)))
        c.fill(Path(CGRect(x: h * 0.92 - railW, y: -h, width: railW, height: h * 2)), with: .color(Color(hex: 0x5A6474)))
        c.fill(Path(CGRect(x: -h * 0.92 + railW * 0.3, y: -h, width: railW * 0.25, height: h * 2)), with: .color(.white.opacity(0.12)))

        var inner = c
        inner.clip(to: Path(local.insetBy(dx: h * 0.3, dy: 0)))
        let ph = phase - floor(phase)
        var chev = Path()
        for k in 0..<3 {
            var t = ph + Double(k) * 0.5
            t -= floor(t)
            let y = h * 1.2 - CGFloat(t) * h * 2.4
            chev.move(to: CGPoint(x: -h * 0.4, y: y + h * 0.28))
            chev.addLine(to: CGPoint(x: 0, y: y))
            chev.addLine(to: CGPoint(x: h * 0.4, y: y + h * 0.28))
        }
        inner.stroke(chev, with: .color(Color(hex: 0x6C7889).opacity(0.75)),
                     style: StrokeStyle(lineWidth: h * 0.13, lineCap: .round, lineJoin: .round))
    }

    // MARK: Buildings

    static func drawBuilding(_ ctx: GraphicsContext, type: BuildingType, dir: Dir, rect: CGRect,
                             working: Bool, progress: Double, time: Double,
                             recipeOutput: ItemType?, flash: Double) {
        let h = rect.width / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let body = rect.insetBy(dx: h * 0.1, dy: h * 0.1)
        let bodyPath = Path(roundedRect: body, cornerRadius: h * 0.28)

        let colors: (UInt32, UInt32) = {
            switch type {
            case .miner: return (0xE6A940, 0x9C6418)
            case .smelter: return (0xC55B3F, 0x73281D)
            case .assembler: return (0x4590C2, 0x22557C)
            case .splitter: return (0x8A73CC, 0x4B3B85)
            case .seller: return (0x44B877, 0x1F6E43)
            case .belt: return (0x2A313D, 0x2A313D)
            }
        }()

        // Shadow
        ctx.fill(Path(roundedRect: body.offsetBy(dx: 0, dy: h * 0.08), cornerRadius: h * 0.28),
                 with: .color(.black.opacity(0.35)))
        ctx.fill(bodyPath, with: .linearGradient(Gradient(colors: [Color(hex: colors.0), Color(hex: colors.1)]),
                                                 startPoint: CGPoint(x: body.midX, y: body.minY),
                                                 endPoint: CGPoint(x: body.midX, y: body.maxY)))
        ctx.stroke(bodyPath, with: .color(.black.opacity(0.55)), lineWidth: max(1, h * 0.06))
        let hi = Path(roundedRect: body.insetBy(dx: h * 0.06, dy: h * 0.06), cornerRadius: h * 0.22)
        ctx.stroke(hi, with: .color(.white.opacity(0.18)), lineWidth: max(0.6, h * 0.04))

        switch type {
        case .miner:
            let pitR = h * 0.46
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - pitR, y: center.y - pitR, width: pitR * 2, height: pitR * 2)),
                     with: .color(Color(hex: 0x3A2A12)))
            let rot = working ? time * 7 : 0.4
            var blades = Path()
            for k in 0..<3 {
                let a = rot + Double(k) * 2 * Double.pi / 3
                let tip = CGPoint(x: center.x + CGFloat(cos(a)) * pitR * 0.92, y: center.y + CGFloat(sin(a)) * pitR * 0.92)
                let l = CGPoint(x: center.x + CGFloat(cos(a + 0.5)) * pitR * 0.3, y: center.y + CGFloat(sin(a + 0.5)) * pitR * 0.3)
                let r = CGPoint(x: center.x + CGFloat(cos(a - 0.5)) * pitR * 0.3, y: center.y + CGFloat(sin(a - 0.5)) * pitR * 0.3)
                blades.move(to: l)
                blades.addLine(to: tip)
                blades.addLine(to: r)
                blades.closeSubpath()
            }
            ctx.fill(blades, with: .color(Color(hex: 0xD9DEE5)))
            let hub = h * 0.14
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - hub, y: center.y - hub, width: hub * 2, height: hub * 2)),
                     with: .color(Color(hex: 0x6B7280)))

        case .smelter:
            let glow = working ? 0.65 + 0.35 * sin(time * 7) : 0.12
            let mouth = CGRect(x: center.x - h * 0.42, y: center.y - h * 0.18, width: h * 0.84, height: h * 0.58)
            ctx.fill(Path(roundedRect: mouth, cornerRadius: h * 0.16), with: .color(Color(hex: 0x200A06)))
            ctx.fill(Path(roundedRect: mouth.insetBy(dx: h * 0.08, dy: h * 0.08), cornerRadius: h * 0.1),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE08A).opacity(glow), Color(hex: 0xFF5A1F).opacity(glow * 0.9), .clear]),
                                           center: CGPoint(x: mouth.midX, y: mouth.maxY), startRadius: 0, endRadius: h * 0.6))
            var bricks = Path()
            bricks.move(to: CGPoint(x: body.minX + h * 0.15, y: center.y - h * 0.38))
            bricks.addLine(to: CGPoint(x: body.maxX - h * 0.15, y: center.y - h * 0.38))
            ctx.stroke(bricks, with: .color(.black.opacity(0.3)), lineWidth: h * 0.05)

        case .assembler:
            let rot = working ? time * 2.2 : 0
            let g = gearPath(center: CGPoint(x: center.x, y: center.y - h * 0.02), radius: h * 0.5, teeth: 8, rotation: rot, hole: 0.38)
            ctx.fill(g, with: .color(Color(hex: 0xCFE3F2)), style: FillStyle(eoFill: true))
            ctx.stroke(g, with: .color(.black.opacity(0.4)), lineWidth: h * 0.04)
            if let out = recipeOutput {
                let s = h * 0.55
                let p = CGPoint(x: body.maxX - s * 0.55, y: body.maxY - s * 0.55)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - s * 0.62, y: p.y - s * 0.62, width: s * 1.24, height: s * 1.24)),
                         with: .color(Color(hex: 0x0F2233)))
                drawItem(ctx, out, at: p, size: s)
            }

        case .splitter:
            var c = ctx
            c.translateBy(x: center.x, y: center.y)
            c.rotate(by: .radians(dir.radians))
            var arrows = Path()
            for a in [-Double.pi / 2, 0, Double.pi / 2] {
                var seg = Path()
                seg.move(to: .zero)
                seg.addLine(to: CGPoint(x: 0, y: -h * 0.5))
                seg.move(to: CGPoint(x: -h * 0.16, y: -h * 0.34))
                seg.addLine(to: CGPoint(x: 0, y: -h * 0.5))
                seg.addLine(to: CGPoint(x: h * 0.16, y: -h * 0.34))
                arrows.addPath(seg, transform: CGAffineTransform(rotationAngle: CGFloat(a)))
            }
            c.stroke(arrows, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: h * 0.1, lineCap: .round, lineJoin: .round))

        case .seller:
            if flash > 0 {
                let rr = h * (0.5 + 0.5 * (1 - flash))
                ctx.stroke(Path(ellipseIn: CGRect(x: center.x - rr, y: center.y - rr, width: rr * 2, height: rr * 2)),
                           with: .color(Theme.accent.opacity(flash)), lineWidth: h * 0.08)
            }
            let coinR = h * 0.46
            let coin = CGRect(x: center.x - coinR, y: center.y - coinR, width: coinR * 2, height: coinR * 2)
            ctx.fill(Path(ellipseIn: coin), with: .linearGradient(Gradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xD99A1E)]),
                                                                 startPoint: CGPoint(x: coin.minX, y: coin.minY),
                                                                 endPoint: CGPoint(x: coin.maxX, y: coin.maxY)))
            ctx.stroke(Path(ellipseIn: coin.insetBy(dx: coinR * 0.18, dy: coinR * 0.18)),
                       with: .color(Color(hex: 0x9A6A10).opacity(0.7)), lineWidth: coinR * 0.08)
            let txt = Text("$").font(.system(size: coinR * 1.15, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: 0x7A4E06))
            ctx.draw(txt, at: center, anchor: .center)

        case .belt:
            break
        }

        // Output marker
        if type == .miner || type.isMachine {
            var c = ctx
            c.translateBy(x: center.x, y: center.y)
            c.rotate(by: .radians(dir.radians))
            var tri = Path()
            tri.move(to: CGPoint(x: 0, y: -h * 0.99))
            tri.addLine(to: CGPoint(x: -h * 0.24, y: -h * 0.7))
            tri.addLine(to: CGPoint(x: h * 0.24, y: -h * 0.7))
            tri.closeSubpath()
            c.fill(tri, with: .color(.white.opacity(0.92)))
            c.stroke(tri, with: .color(.black.opacity(0.5)), lineWidth: h * 0.04)
        }

        // Progress
        if (type == .miner || type.isMachine) && progress > 0 {
            let bar = CGRect(x: center.x - h * 0.6, y: body.maxY - h * 0.2, width: h * 1.2, height: h * 0.1)
            ctx.fill(Path(roundedRect: bar, cornerRadius: h * 0.05), with: .color(.black.opacity(0.45)))
            var fill = bar
            fill.size.width *= CGFloat(min(1, progress))
            ctx.fill(Path(roundedRect: fill, cornerRadius: h * 0.05), with: .color(Theme.accent))
        }
    }
}

// MARK: - Small SwiftUI wrappers

struct ItemIcon: View {
    let item: ItemType
    var size: CGFloat = 22

    var body: some View {
        Canvas { ctx, sz in
            Art.drawItem(ctx, item, at: CGPoint(x: sz.width / 2, y: sz.height / 2), size: min(sz.width, sz.height) * 0.86)
        }
        .frame(width: size, height: size)
    }
}

struct BuildingIcon: View {
    let type: BuildingType
    var dir: Dir = .up
    var recipeOutput: ItemType? = nil
    var size: CGFloat = 36

    var body: some View {
        Canvas { ctx, sz in
            let rect = CGRect(origin: .zero, size: sz)
            if type == .belt {
                Art.drawBelt(ctx, rect: rect, dir: dir, phase: 0.25)
            } else {
                Art.drawBuilding(ctx, type: type, dir: dir, rect: rect, working: false, progress: 0,
                                 time: 0, recipeOutput: recipeOutput, flash: 0)
            }
        }
        .frame(width: size, height: size)
    }
}
