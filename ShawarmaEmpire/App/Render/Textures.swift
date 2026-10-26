import UIKit
import SceneKit

/// Procedural textures — everything is drawn in code.
enum Tex {
    /// Draws into an explicit 8-bit RGBA bitmap. (UIGraphicsImageRenderer may pick a single-channel
    /// format for grey-only drawings, which the simulator's Metal driver rejects as a texture.)
    static func render(_ w: Int, _ h: Int, opaque: Bool = false, _ draw: (CGContext) -> Void) -> UIImage {
        let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: info) else { return UIImage() }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(ctx)
        draw(ctx)
        UIGraphicsPopContext()
        guard let cg = ctx.makeImage() else { return UIImage() }
        return UIImage(cgImage: cg)
    }

    static func image(width: Int, height: Int, pixels: [UInt8]) -> UIImage {
        var data = pixels
        let cs = CGColorSpaceCreateDeviceRGB()
        let cg = data.withUnsafeMutableBytes { buf -> CGImage? in
            let ctx = CGContext(data: buf.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: cs,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            return ctx?.makeImage()
        }
        guard let cg else { return UIImage() }
        return UIImage(cgImage: cg)
    }

    static func font(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let d = base.fontDescriptor.withDesign(.rounded) { return UIFont(descriptor: d, size: size) }
        return base
    }

    static func text(_ s: String, in rect: CGRect, font: UIFont, color: UIColor, align: NSTextAlignment = .center,
                     stroke: UIColor? = nil, strokeWidth: CGFloat = 0) {
        let p = NSMutableParagraphStyle()
        p.alignment = align
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: p]
        if let stroke {
            attrs[.strokeColor] = stroke
            attrs[.strokeWidth] = -strokeWidth
        }
        (s as NSString).draw(in: rect, withAttributes: attrs)
    }

    // MARK: Basics

    static let softCircle: UIImage = render(64, 64) { c in
        let colors = [UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0.35).cgColor,
                      UIColor(white: 1, alpha: 0).cgColor] as CFArray
        let locs: [CGFloat] = [0, 0.45, 1]
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) {
            c.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                                 endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
    }

    static let spark: UIImage = render(64, 64) { c in
        let colors = [UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
        let locs: [CGFloat] = [0, 1]
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) {
            c.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                                 endCenter: CGPoint(x: 32, y: 32), endRadius: 14, options: [])
        }
        c.setFillColor(UIColor.white.cgColor)
        c.move(to: CGPoint(x: 32, y: 2))
        c.addLine(to: CGPoint(x: 36, y: 28))
        c.addLine(to: CGPoint(x: 62, y: 32))
        c.addLine(to: CGPoint(x: 36, y: 36))
        c.addLine(to: CGPoint(x: 32, y: 62))
        c.addLine(to: CGPoint(x: 28, y: 36))
        c.addLine(to: CGPoint(x: 2, y: 32))
        c.addLine(to: CGPoint(x: 28, y: 28))
        c.closePath()
        c.fillPath()
    }

    static let raindrop: UIImage = render(16, 64) { c in
        let colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 0.9).cgColor] as CFArray
        let locs: [CGFloat] = [0, 1]
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) {
            c.addRect(CGRect(x: 6, y: 0, width: 4, height: 64))
            c.clip()
            c.drawLinearGradient(g, start: CGPoint(x: 8, y: 0), end: CGPoint(x: 8, y: 64), options: [])
        }
    }

    // MARK: Sky

    static let horizon = UIColor(hex: 0xD6EAF5)

    static let sky: UIImage = {
        let w = 256, h = 128
        struct C { var r, g, b: Double }
        func mix(_ a: C, _ b: C, _ t: Double) -> C { C(r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t) }
        let zenith = C(r: 0.30, g: 0.58, b: 0.88), mid = C(r: 0.60, g: 0.79, b: 0.94)
        let hor = C(r: 0.93, g: 0.95, b: 0.95), below = C(r: 0.62, g: 0.70, b: 0.74)
        var px = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            let v = Double(y) / Double(h - 1)
            let col: C
            if v < 0.5 {
                let t = v / 0.5
                col = t < 0.6 ? mix(zenith, mid, t / 0.6) : mix(mid, hor, (t - 0.6) / 0.4)
            } else {
                col = mix(hor, below, min(1, (v - 0.5) / 0.25))
            }
            for x in 0..<w {
                let o = (y * w + x) * 4
                px[o] = UInt8(min(255, col.r * 255))
                px[o + 1] = UInt8(min(255, col.g * 255))
                px[o + 2] = UInt8(min(255, col.b * 255))
            }
        }
        return image(width: w, height: h, pixels: px)
    }()

    // MARK: Surfaces

    static func tiles(_ a: UInt32, _ b: UInt32, size: Int = 128, cells: Int = 4) -> UIImage {
        render(size, size, opaque: true) { c in
            let s = CGFloat(size) / CGFloat(cells)
            for y in 0..<cells {
                for x in 0..<cells {
                    c.setFillColor(UIColor(hex: (x + y) % 2 == 0 ? a : b).cgColor)
                    c.fill(CGRect(x: CGFloat(x) * s, y: CGFloat(y) * s, width: s, height: s))
                }
            }
            c.setStrokeColor(UIColor(white: 0, alpha: 0.08).cgColor)
            c.setLineWidth(2)
            for k in 0...cells {
                let p = CGFloat(k) * s
                c.move(to: CGPoint(x: p, y: 0))
                c.addLine(to: CGPoint(x: p, y: CGFloat(size)))
                c.move(to: CGPoint(x: 0, y: p))
                c.addLine(to: CGPoint(x: CGFloat(size), y: p))
            }
            c.strokePath()
        }
    }

    static let sidewalk: UIImage = render(128, 128, opaque: true) { c in
        c.setFillColor(UIColor(hex: 0x9C968C).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
        for y in 0..<4 {
            for x in 0..<4 {
                let shade = 0.92 + 0.08 * CGFloat(hash01(x, y, 3))
                c.setFillColor(UIColor(red: 0.70 * shade, green: 0.68 * shade, blue: 0.64 * shade, alpha: 1).cgColor)
                c.fill(CGRect(x: x * 32 + 1, y: y * 32 + 1, width: 30, height: 30))
            }
        }
    }

    static let road: UIImage = render(128, 256, opaque: true) { c in
        c.setFillColor(UIColor(hex: 0x3D4045).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 128, height: 256))
        for k in 0..<200 {
            let x = CGFloat(hash01(k, 1, 5)) * 128, y = CGFloat(hash01(k, 2, 5)) * 256
            c.setFillColor(UIColor(white: hash01(k, 3, 5) > 0.5 ? 0.3 : 0.2, alpha: 0.5).cgColor)
            c.fill(CGRect(x: x, y: y, width: 2, height: 2))
        }
        // Dashed centre line (v = 0.5) and edge lines
        c.setFillColor(UIColor(hex: 0xF2F2F2).cgColor)
        c.fill(CGRect(x: 8, y: 125, width: 56, height: 6))
        c.setFillColor(UIColor(white: 0.85, alpha: 1).cgColor)
        c.fill(CGRect(x: 0, y: 6, width: 128, height: 4))
        c.fill(CGRect(x: 0, y: 246, width: 128, height: 4))
    }

    static let brick: UIImage = render(128, 128, opaque: true) { c in
        c.setFillColor(UIColor(hex: 0xD9CBB5).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
        for row in 0..<8 {
            let off = row % 2 == 0 ? 0 : 16
            for col in -1..<4 {
                let shade = 0.88 + 0.14 * CGFloat(hash01(row, col, 9))
                c.setFillColor(UIColor(red: 0.70 * shade, green: 0.33 * shade, blue: 0.24 * shade, alpha: 1).cgColor)
                c.fill(CGRect(x: col * 32 + off + 1, y: row * 16 + 1, width: 30, height: 14))
            }
        }
    }

    static let planks: UIImage = render(128, 128, opaque: true) { c in
        for i in 0..<8 {
            let shade = 0.9 + 0.12 * CGFloat(hash01(i, 4, 2))
            c.setFillColor(UIColor(red: 0.62 * shade, green: 0.43 * shade, blue: 0.27 * shade, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: i * 16, width: 128, height: 15))
            c.setFillColor(UIColor(white: 0, alpha: 0.25).cgColor)
            c.fill(CGRect(x: 0, y: i * 16 + 15, width: 128, height: 1))
        }
    }

    static func stripes(_ a: UInt32, _ b: UInt32) -> UIImage {
        render(128, 32, opaque: true) { c in
            for i in 0..<8 {
                c.setFillColor(UIColor(hex: i % 2 == 0 ? a : b).cgColor)
                c.fill(CGRect(x: CGFloat(i) * 16, y: 0, width: 16, height: 32))
            }
        }
    }

    // MARK: Facades

    /// Building facade: diffuse + emission (lit windows at night).
    static func facade(wall: UInt32, window: UInt32, cols: Int, rows: Int, seed: Int, glassy: Bool = false) -> (UIImage, UIImage) {
        let w = 256, h = 256
        let cw = CGFloat(w) / CGFloat(cols), rh = CGFloat(h) / CGFloat(rows)
        let diffuse = render(w, h, opaque: true) { c in
            c.setFillColor(UIColor(hex: wall).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: h))
            for r in 0..<rows {
                for k in 0..<cols {
                    let rect = glassy
                        ? CGRect(x: CGFloat(k) * cw + 2, y: CGFloat(r) * rh + 2, width: cw - 4, height: rh - 4)
                        : CGRect(x: CGFloat(k) * cw + cw * 0.22, y: CGFloat(r) * rh + rh * 0.2, width: cw * 0.56, height: rh * 0.58)
                    let shade = 0.85 + 0.2 * CGFloat(hash01(k, r, seed))
                    let base = UIColor(hex: window)
                    var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
                    base.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
                    c.setFillColor(UIColor(red: rr * shade, green: gg * shade, blue: bb * shade, alpha: 1).cgColor)
                    c.fill(rect)
                    if !glassy {
                        c.setFillColor(UIColor(white: 1, alpha: 0.25).cgColor)
                        c.fill(CGRect(x: rect.minX, y: rect.maxY, width: rect.width, height: 3))
                    }
                }
            }
        }
        let emission = render(w, h, opaque: true) { c in
            c.setFillColor(UIColor.black.cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: h))
            for r in 0..<rows {
                for k in 0..<cols where hash01(k, r, seed + 77) < 0.55 {
                    let rect = glassy
                        ? CGRect(x: CGFloat(k) * cw + 2, y: CGFloat(r) * rh + 2, width: cw - 4, height: rh - 4)
                        : CGRect(x: CGFloat(k) * cw + cw * 0.22, y: CGFloat(r) * rh + rh * 0.2, width: cw * 0.56, height: rh * 0.58)
                    let warm = hash01(k, r, seed + 5) > 0.3
                    c.setFillColor((warm ? UIColor(hex: 0xFFD27A) : UIColor(hex: 0xBFE3FF)).cgColor)
                    c.fill(rect)
                }
            }
        }
        return (diffuse, emission)
    }

    // MARK: Signs & boards

    static func sign(_ text: String, bg: UInt32, fg: UInt32, width: Int = 512, height: Int = 112) -> UIImage {
        render(width, height) { c in
            let rect = CGRect(x: 4, y: 4, width: width - 8, height: height - 8)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 22)
            c.setFillColor(UIColor(hex: bg).cgColor)
            c.addPath(path.cgPath)
            c.fillPath()
            c.setStrokeColor(UIColor(hex: fg).cgColor)
            c.setLineWidth(5)
            c.addPath(UIBezierPath(roundedRect: rect.insetBy(dx: 9, dy: 9), cornerRadius: 15).cgPath)
            c.strokePath()
            UIGraphicsPushContext(c)
            var size: CGFloat = 70
            let maxW = CGFloat(width) - 70
            while size > 30 && (text as NSString).size(withAttributes: [.font: font(size, .black)]).width > maxW { size -= 2 }
            let f = font(size, .black)
            let th = (text as NSString).size(withAttributes: [.font: f]).height
            Tex.text(text, in: CGRect(x: 0, y: (CGFloat(height) - th) / 2, width: CGFloat(width), height: th),
                     font: f, color: UIColor(hex: fg))
            UIGraphicsPopContext()
        }
    }

    static func menuBoard(_ dishes: [Dish], icons: [String: UIImage], prices: [Double]) -> UIImage {
        render(512, 256) { c in
            let rect = CGRect(x: 0, y: 0, width: 512, height: 256)
            c.setFillColor(UIColor(hex: 0x23272B).cgColor)
            c.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 18).cgPath)
            c.fillPath()
            c.setStrokeColor(UIColor(hex: 0x8B6B3E).cgColor)
            c.setLineWidth(10)
            c.addPath(UIBezierPath(roundedRect: rect.insetBy(dx: 5, dy: 5), cornerRadius: 14).cgPath)
            c.strokePath()
            UIGraphicsPushContext(c)
            Tex.text("МЕНЮ", in: CGRect(x: 0, y: 14, width: 512, height: 44), font: font(36, .black), color: UIColor(hex: 0xFFE082))
            for (k, d) in dishes.enumerated() {
                let x = CGFloat(k % 2) * 250 + 22, y = CGFloat(k / 2) * 86 + 66
                if let img = icons[d.iconKey] {
                    img.draw(in: CGRect(x: x, y: y, width: 70, height: 70))
                } else {
                    c.setFillColor(UIColor(hex: d.hex).cgColor)
                    c.fillEllipse(in: CGRect(x: x + 12, y: y + 12, width: 46, height: 46))
                }
                let price = k < prices.count && prices[k] > 0 ? Fmt.money(prices[k]) : "скоро"
                Tex.text(d.title, in: CGRect(x: x + 74, y: y + 8, width: 160, height: 30), font: font(22, .bold),
                         color: .white, align: .left)
                Tex.text(price, in: CGRect(x: x + 74, y: y + 36, width: 160, height: 30), font: font(22, .heavy),
                         color: UIColor(hex: 0xFFD54F), align: .left)
            }
            UIGraphicsPopContext()
        }
    }

    static func lockedSign(dish: Dish, price: String, icon: UIImage?) -> UIImage {
        render(256, 256) { c in
            let rect = CGRect(x: 6, y: 6, width: 244, height: 244)
            c.setFillColor(UIColor(hex: 0xFFC94A).cgColor)
            c.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 34).cgPath)
            c.fillPath()
            c.setStrokeColor(UIColor(hex: 0x7A4E06).cgColor)
            c.setLineWidth(8)
            c.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 34).cgPath)
            c.strokePath()
            if let icon {
                icon.draw(in: CGRect(x: 63, y: 18, width: 130, height: 130))
            } else {
                c.setFillColor(UIColor(hex: dish.hex).cgColor)
                c.fillEllipse(in: CGRect(x: 88, y: 40, width: 80, height: 80))
            }
            UIGraphicsPushContext(c)
            Tex.text("ОТКРЫТЬ", in: CGRect(x: 0, y: 146, width: 256, height: 34), font: font(26, .black), color: UIColor(hex: 0x6B4405))
            Tex.text(price, in: CGRect(x: 0, y: 180, width: 256, height: 52), font: font(40, .black), color: UIColor(hex: 0x3A2402))
            UIGraphicsPopContext()
        }
    }

    static let chalkboard: UIImage = render(128, 160) { c in
        c.setFillColor(UIColor(hex: 0x6B4428).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 128, height: 160))
        c.setFillColor(UIColor(hex: 0x2E3B32).cgColor)
        c.fill(CGRect(x: 8, y: 8, width: 112, height: 144))
        UIGraphicsPushContext(c)
        Tex.text("ВКУСНО", in: CGRect(x: 0, y: 22, width: 128, height: 30), font: font(22, .black), color: UIColor(hex: 0xFFF59D))
        Tex.text("ГОРЯЧО", in: CGRect(x: 0, y: 58, width: 128, height: 30), font: font(22, .black), color: .white)
        Tex.text("БЫСТРО!", in: CGRect(x: 0, y: 94, width: 128, height: 30), font: font(22, .black), color: UIColor(hex: 0x80DEEA))
        UIGraphicsPopContext()
    }

    // MARK: Bubbles & labels

    private static var bubbleCache: [String: UIImage] = [:]

    /// Speech bubble with the dishes a customer wants; collected ones get a green check.
    static func orderBubble(_ order: [Dish], collected: Int, vip: Bool, icons: [String: UIImage]) -> UIImage {
        let ready = order.allSatisfy { icons[$0.iconKey] != nil }
        let key = order.map { $0.rawValue }.joined(separator: ",") + "|\(collected)|\(vip)|\(ready)"
        if let img = bubbleCache[key] { return img }
        let n = max(1, order.count)
        let w = 40 + n * 96, h = 150
        let img = render(w, h) { c in
            let body = CGRect(x: 6, y: 6, width: w - 12, height: 112)
            let path = UIBezierPath(roundedRect: body, cornerRadius: 34)
            path.move(to: CGPoint(x: CGFloat(w) / 2 - 16, y: body.maxY - 1))
            path.addLine(to: CGPoint(x: CGFloat(w) / 2, y: body.maxY + 24))
            path.addLine(to: CGPoint(x: CGFloat(w) / 2 + 16, y: body.maxY - 1))
            path.close()
            c.setFillColor((vip ? UIColor(hex: 0xFFE082) : UIColor.white).cgColor)
            c.addPath(path.cgPath)
            c.fillPath()
            c.setStrokeColor((vip ? UIColor(hex: 0xC79100) : UIColor(white: 0, alpha: 0.18)).cgColor)
            c.setLineWidth(vip ? 6 : 3)
            c.addPath(UIBezierPath(roundedRect: body, cornerRadius: 34).cgPath)
            c.strokePath()
            for (k, d) in order.enumerated() {
                let r = CGRect(x: 26 + k * 96, y: 18, width: 88, height: 88)
                if let icon = icons[d.iconKey] {
                    icon.draw(in: r)
                } else {
                    c.setFillColor(UIColor(hex: d.hex).cgColor)
                    c.fillEllipse(in: r.insetBy(dx: 16, dy: 16))
                }
                if k < collected {
                    c.setFillColor(UIColor(hex: 0x2EB872).cgColor)
                    c.fillEllipse(in: CGRect(x: r.maxX - 34, y: r.maxY - 34, width: 34, height: 34))
                    c.setStrokeColor(UIColor.white.cgColor)
                    c.setLineWidth(5)
                    c.setLineCap(.round)
                    c.move(to: CGPoint(x: r.maxX - 26, y: r.maxY - 17))
                    c.addLine(to: CGPoint(x: r.maxX - 19, y: r.maxY - 10))
                    c.addLine(to: CGPoint(x: r.maxX - 8, y: r.maxY - 25))
                    c.strokePath()
                }
            }
        }
        if bubbleCache.count > 400 { bubbleCache.removeAll() }
        bubbleCache[key] = img
        return img
    }

    static let heartBubble: UIImage = render(128, 128) { c in
        c.setFillColor(UIColor.white.cgColor)
        c.fillEllipse(in: CGRect(x: 4, y: 4, width: 120, height: 120))
        c.setFillColor(UIColor(hex: 0xFF4D6D).cgColor)
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 64, y: 100))
        p.addCurve(to: CGPoint(x: 22, y: 50), controlPoint1: CGPoint(x: 40, y: 84), controlPoint2: CGPoint(x: 22, y: 70))
        p.addArc(withCenter: CGPoint(x: 43, y: 48), radius: 21, startAngle: .pi, endAngle: 0, clockwise: true)
        p.addArc(withCenter: CGPoint(x: 85, y: 48), radius: 21, startAngle: .pi, endAngle: 0, clockwise: true)
        p.addCurve(to: CGPoint(x: 64, y: 100), controlPoint1: CGPoint(x: 106, y: 70), controlPoint2: CGPoint(x: 88, y: 84))
        c.addPath(p.cgPath)
        c.fillPath()
    }

    static let angryBubble: UIImage = render(128, 128) { c in
        c.setFillColor(UIColor(hex: 0xFF5252).cgColor)
        c.fillEllipse(in: CGRect(x: 4, y: 4, width: 120, height: 120))
        c.setStrokeColor(UIColor.white.cgColor)
        c.setLineWidth(9)
        c.setLineCap(.round)
        c.move(to: CGPoint(x: 34, y: 42)); c.addLine(to: CGPoint(x: 56, y: 54))
        c.move(to: CGPoint(x: 94, y: 42)); c.addLine(to: CGPoint(x: 72, y: 54))
        c.strokePath()
        c.setFillColor(UIColor.white.cgColor)
        c.fillEllipse(in: CGRect(x: 40, y: 58, width: 14, height: 14))
        c.fillEllipse(in: CGRect(x: 74, y: 58, width: 14, height: 14))
        c.move(to: CGPoint(x: 40, y: 98))
        c.addQuadCurve(to: CGPoint(x: 88, y: 98), control: CGPoint(x: 64, y: 80))
        c.strokePath()
    }

    private static var labelCache: [String: UIImage] = [:]

    static func label(_ text: String, color: UInt32 = 0xFFD54A) -> UIImage {
        let key = text + "|\(color)"
        if let img = labelCache[key] { return img }
        let f = font(46, .black)
        let size = (text as NSString).size(withAttributes: [.font: f])
        let w = Int(ceil(size.width)) + 16, h = Int(ceil(size.height)) + 12
        let img = render(w, h) { c in
            UIGraphicsPushContext(c)
            let rect = CGRect(x: 8, y: 6, width: size.width, height: size.height)
            (text as NSString).draw(in: rect.offsetBy(dx: 0, dy: 3), withAttributes: [.font: f, .foregroundColor: UIColor(white: 0, alpha: 0.45)])
            (text as NSString).draw(in: rect, withAttributes: [.font: f, .foregroundColor: UIColor(hex: color),
                                                               .strokeColor: UIColor(hex: 0x4A2E00), .strokeWidth: -7])
            UIGraphicsPopContext()
        }
        if labelCache.count > 300 { labelCache.removeAll() }
        labelCache[key] = img
        return img
    }

    static let waterNormal: UIImage = {
        let n = 128
        let waves: [(Double, Double, Double, Double)] = [(1, 2, 0.6, 0.3), (3, -1, 0.35, 1.7), (-2, 3, 0.3, 4.1),
                                                         (5, 2, 0.15, 2.2), (-4, -5, 0.12, 0.9), (7, -3, 0.08, 5.0)]
        func height(_ x: Double, _ y: Double) -> Double {
            var h = 0.0
            for (kx, ky, a, ph) in waves { h += a * sin(2 * Double.pi * (kx * x + ky * y) + ph) }
            return h
        }
        var px = [UInt8](repeating: 255, count: n * n * 4)
        let e = 1.0 / Double(n)
        for y in 0..<n {
            for x in 0..<n {
                let fx = Double(x) / Double(n), fy = Double(y) / Double(n)
                let dx = (height(fx + e, fy) - height(fx - e, fy)) / (2 * e) * 0.012
                let dy = (height(fx, fy + e) - height(fx, fy - e)) / (2 * e) * 0.012
                var nx = -dx, ny = -dy, nz = 1.0
                let l = sqrt(nx * nx + ny * ny + nz * nz)
                nx /= l; ny /= l; nz /= l
                let o = (y * n + x) * 4
                px[o] = UInt8((nx * 0.5 + 0.5) * 255)
                px[o + 1] = UInt8((ny * 0.5 + 0.5) * 255)
                px[o + 2] = UInt8((nz * 0.5 + 0.5) * 255)
            }
        }
        return image(width: n, height: n, pixels: px)
    }()

    static func metroSign() -> UIImage {
        render(128, 128) { c in
            c.setFillColor(UIColor(hex: 0xD32F2F).cgColor)
            c.fillEllipse(in: CGRect(x: 4, y: 4, width: 120, height: 120))
            UIGraphicsPushContext(c)
            Tex.text("M", in: CGRect(x: 0, y: 18, width: 128, height: 100), font: font(84, .black), color: .white)
            UIGraphicsPopContext()
        }
    }

    static let shutter: UIImage = render(128, 128, opaque: true) { c in
        for i in 0..<16 {
            c.setFillColor(UIColor(white: i % 2 == 0 ? 0.62 : 0.55, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: i * 8, width: 128, height: 8))
        }
    }

    static let deliveryBox: UIImage = render(128, 128, opaque: true) { c in
        c.setFillColor(UIColor(hex: 0x43A047).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
        c.setFillColor(UIColor.white.cgColor)
        c.fillEllipse(in: CGRect(x: 30, y: 30, width: 68, height: 68))
        c.setFillColor(UIColor(hex: 0x43A047).cgColor)
        c.fill(CGRect(x: 58, y: 42, width: 12, height: 44))
        c.fill(CGRect(x: 42, y: 58, width: 44, height: 12))
    }
}
