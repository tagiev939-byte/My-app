import UIKit
import SceneKit

/// Procedurally generated textures. Everything is drawn in code so the app ships without image assets.
enum Tex {
    static func render(_ w: Int, _ h: Int, opaque: Bool = false, _ draw: (CGContext) -> Void) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        f.opaque = opaque
        let r = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: f)
        return r.image { ctx in draw(ctx.cgContext) }
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

    struct RGB {
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat

        init(_ hex: UInt32) {
            r = CGFloat((hex >> 16) & 0xFF) / 255
            g = CGFloat((hex >> 8) & 0xFF) / 255
            b = CGFloat(hex & 0xFF) / 255
        }

        init(r: CGFloat, g: CGFloat, b: CGFloat) {
            self.r = r
            self.g = g
            self.b = b
        }

        func mix(_ o: RGB, _ t: CGFloat) -> RGB {
            RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
        }

        func scaled(_ k: CGFloat) -> RGB { RGB(r: min(1, r * k), g: min(1, g * k), b: min(1, b * k)) }

        var gray: RGB {
            let l = r * 0.3 + g * 0.59 + b * 0.11
            return RGB(r: l, g: l, b: l)
        }

        var cg: CGColor { UIColor(red: r, green: g, blue: b, alpha: 1).cgColor }
    }

    // MARK: Particles & UI

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

    // MARK: Surfaces

    /// Conveyor rubber for one tile: ribs across the belt and a faint arrow towards the output (image top).
    static let belt: UIImage = render(64, 128, opaque: true) { c in
        c.setFillColor(UIColor(hex: 0x30343B).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 64, height: 128))
        for i in 0..<6 {
            let y = CGFloat(i) * 128 / 6
            c.setFillColor(UIColor(hex: 0x23262B).cgColor)
            c.fill(CGRect(x: 0, y: y + 8, width: 64, height: 7))
            c.setFillColor(UIColor(hex: 0x41464F).cgColor)
            c.fill(CGRect(x: 0, y: y + 6, width: 64, height: 2))
        }
        c.setStrokeColor(UIColor(hex: 0x555B66).cgColor)
        c.setLineWidth(5)
        c.setLineCap(.round)
        c.setLineJoin(.round)
        c.move(to: CGPoint(x: 20, y: 74))
        c.addLine(to: CGPoint(x: 32, y: 60))
        c.addLine(to: CGPoint(x: 44, y: 74))
        c.strokePath()
        c.setFillColor(UIColor(white: 0, alpha: 0.35).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 3, height: 128))
        c.fill(CGRect(x: 61, y: 0, width: 3, height: 128))
    }

    static let stripes: UIImage = render(128, 32, opaque: true) { c in
        for i in 0..<8 {
            c.setFillColor((i % 2 == 0 ? UIColor(hex: 0xE04B3C) : UIColor(hex: 0xFFF6E8)).cgColor)
            c.fill(CGRect(x: CGFloat(i) * 16, y: 0, width: 16, height: 32))
        }
    }

    static let hazard: UIImage = render(64, 64, opaque: true) { c in
        c.setFillColor(UIColor(hex: 0x23262B).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        c.setFillColor(UIColor(hex: 0xF2B33D).cgColor)
        for i in -2..<4 {
            let x = CGFloat(i) * 24
            c.move(to: CGPoint(x: x, y: 64))
            c.addLine(to: CGPoint(x: x + 12, y: 64))
            c.addLine(to: CGPoint(x: x + 76, y: 0))
            c.addLine(to: CGPoint(x: x + 64, y: 0))
            c.closePath()
            c.fillPath()
        }
    }

    /// Cliff texture for chunk sides: grass lip on top, layered soil below.
    static let cliff: UIImage = render(64, 128, opaque: true) { c in
        let bands: [(UInt32, CGFloat)] = [(0x6FAE4E, 10), (0x5A8F3F, 4), (0x8B5E3C, 30), (0x7A5034, 26),
                                          (0x6B4630, 30), (0x5C3D2A, 28)]
        var y: CGFloat = 0
        for (hex, h) in bands {
            c.setFillColor(UIColor(hex: hex).cgColor)
            c.fill(CGRect(x: 0, y: y, width: 64, height: h))
            y += h
        }
        for i in 0..<40 {
            let px = CGFloat(tileHash(i, 3, 1) * 64), py = 16 + CGFloat(tileHash(i, 5, 2) * 110)
            c.setFillColor(UIColor(white: 0, alpha: 0.12).cgColor)
            c.fill(CGRect(x: px, y: py, width: 6, height: 3))
        }
    }

    // MARK: Sky & water

    static let horizon = UIColor(hex: 0xCFE6F2)

    static let sky: UIImage = {
        let w = 256, h = 128
        let zenith = RGB(0x4E97DC), mid = RGB(0x9CC9EC), hor = RGB(0xE6F1F4), below = RGB(0x8FB4C8)
        var px = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            let v = CGFloat(y) / CGFloat(h - 1)
            let col: RGB
            if v < 0.5 {
                let t = v / 0.5
                col = t < 0.6 ? zenith.mix(mid, t / 0.6) : mid.mix(hor, (t - 0.6) / 0.4)
            } else {
                col = hor.mix(below, min(1, (v - 0.5) / 0.25))
            }
            for x in 0..<w {
                // Soft warm glow towards the sun direction
                let u = CGFloat(x) / CGFloat(w)
                let du = abs(u - 0.3)
                let glow = max(0, 1 - du * 5) * max(0, 1 - abs(v - 0.42) * 6) * 0.35
                let o = (y * w + x) * 4
                px[o] = UInt8(min(255, (col.r + glow * 0.9) * 255))
                px[o + 1] = UInt8(min(255, (col.g + glow * 0.75) * 255))
                px[o + 2] = UInt8(min(255, (col.b + glow * 0.45) * 255))
                px[o + 3] = 255
            }
        }
        return image(width: w, height: h, pixels: px)
    }()

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
                px[o + 3] = 255
            }
        }
        return image(width: n, height: n, pixels: px)
    }()

    /// Rounded turquoise halo around the island (shallow water).
    static let shallow: UIImage = {
        let n = 256
        var px = [UInt8](repeating: 0, count: n * n * 4)
        let inner = 0.36, outer = 0.5
        for y in 0..<n {
            for x in 0..<n {
                let fx = abs(Double(x) / Double(n - 1) - 0.5), fy = abs(Double(y) / Double(n - 1) - 0.5)
                // rounded-square distance
                let r = 0.06
                let qx = max(fx - (inner - r), 0), qy = max(fy - (inner - r), 0)
                let d = sqrt(qx * qx + qy * qy) + (inner - r)
                let t = max(0, min(1, (d - inner) / (outer - inner)))
                let a = (1 - t) * (1 - t) * 0.75
                let o = (y * n + x) * 4
                // premultiplied
                px[o] = UInt8(0.45 * a * 255)
                px[o + 1] = UInt8(0.86 * a * 255)
                px[o + 2] = UInt8(0.86 * a * 255)
                px[o + 3] = UInt8(a * 255)
            }
        }
        return image(width: n, height: n, pixels: px)
    }()

    // MARK: Ground

    static let grass = RGB(0x78AE55)

    static func ground(_ world: World, chunk c: Int, owned: Bool) -> UIImage {
        let px = 40, n = World.chunk
        let cx = c % World.chunks, cy = c / World.chunks
        return render(px * n, px * n, opaque: true) { ctx in
            for ty in 0..<n {
                for tx in 0..<n {
                    let x = cx * n + tx, y = cy * n + ty
                    let r = world.resource(x, y)
                    let h = CGFloat(tileHash(x, y, 1, world.seed))
                    var col = r == .none ? grass : grass.mix(RGB(r.groundHex), 0.82)
                    col = col.scaled(0.95 + 0.08 * h + ((x + y) % 2 == 0 ? 0.025 : 0))
                    if !owned { col = col.mix(col.gray, 0.45).scaled(0.78) }
                    let rect = CGRect(x: tx * px, y: ty * px, width: px, height: px)
                    ctx.setFillColor(col.cg)
                    ctx.fill(rect)

                    // Small details: grass blades or pebbles
                    for k in 0..<7 {
                        let hx = CGFloat(tileHash(x, y, 10 + k, world.seed))
                        let hy = CGFloat(tileHash(x, y, 30 + k, world.seed))
                        let shade = col.scaled(r == .none ? (k % 2 == 0 ? 0.86 : 1.1) : (k % 2 == 0 ? 0.75 : 1.2))
                        ctx.setFillColor(shade.cg)
                        let dot = r == .none ? CGRect(x: 0, y: 0, width: 2, height: 4) : CGRect(x: 0, y: 0, width: 4, height: 3)
                        ctx.fill(dot.offsetBy(dx: rect.minX + 4 + hx * CGFloat(px - 10), dy: rect.minY + 4 + hy * CGFloat(px - 10)))
                    }

                    ctx.setStrokeColor(UIColor(white: 0, alpha: owned ? 0.11 : 0.06).cgColor)
                    ctx.setLineWidth(1)
                    ctx.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
                }
            }
        }
    }

    // MARK: Signs

    static func sign(price: String) -> UIImage {
        render(320, 200) { c in
            let rect = CGRect(x: 6, y: 6, width: 308, height: 188)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 28)
            c.setFillColor(UIColor(hex: 0xFFC94A).cgColor)
            c.addPath(path.cgPath)
            c.fillPath()
            c.setStrokeColor(UIColor(hex: 0x7A4E06).cgColor)
            c.setLineWidth(8)
            c.addPath(path.cgPath)
            c.strokePath()

            UIGraphicsPushContext(c)
            let p = NSMutableParagraphStyle()
            p.alignment = .center
            let small = roundedFont(30, .bold)
            let big = roundedFont(74, .heavy)
            ("Участок" as NSString).draw(in: CGRect(x: 0, y: 26, width: 320, height: 40),
                                         withAttributes: [.font: small, .foregroundColor: UIColor(hex: 0x6B4405), .paragraphStyle: p])
            (price as NSString).draw(in: CGRect(x: 0, y: 70, width: 320, height: 100),
                                     withAttributes: [.font: big, .foregroundColor: UIColor(hex: 0x3A2402), .paragraphStyle: p])
            UIGraphicsPopContext()
        }
    }

    static func roundedFont(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let d = base.fontDescriptor.withDesign(.rounded) { return UIFont(descriptor: d, size: size) }
        return base
    }

    /// Status bubble shown above idle machines.
    static func bubble(symbol: String, color: UIColor) -> UIImage {
        render(96, 96) { c in
            c.setFillColor(UIColor(white: 0, alpha: 0.25).cgColor)
            c.fillEllipse(in: CGRect(x: 8, y: 12, width: 80, height: 80))
            c.setFillColor(color.cgColor)
            c.fillEllipse(in: CGRect(x: 8, y: 6, width: 80, height: 80))
            c.setStrokeColor(UIColor.white.cgColor)
            c.setLineWidth(6)
            c.strokeEllipse(in: CGRect(x: 11, y: 9, width: 74, height: 74))
            UIGraphicsPushContext(c)
            let p = NSMutableParagraphStyle()
            p.alignment = .center
            (symbol as NSString).draw(in: CGRect(x: 0, y: 14, width: 96, height: 70),
                                      withAttributes: [.font: roundedFont(50, .black), .foregroundColor: UIColor.white, .paragraphStyle: p])
            UIGraphicsPopContext()
        }
    }

    private static var labelCache: [String: UIImage] = [:]

    /// Gold text with a dark outline, used for floating income numbers.
    static func label(_ text: String) -> UIImage {
        if let img = labelCache[text] { return img }
        let font = roundedFont(46, .black)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attrs)
        let w = Int(ceil(size.width)) + 16, h = Int(ceil(size.height)) + 12
        let img = render(w, h) { c in
            UIGraphicsPushContext(c)
            let rect = CGRect(x: 8, y: 6, width: size.width, height: size.height)
            (text as NSString).draw(in: rect.offsetBy(dx: 0, dy: 3), withAttributes: [
                .font: font, .foregroundColor: UIColor(white: 0, alpha: 0.45)])
            (text as NSString).draw(in: rect, withAttributes: [
                .font: font, .foregroundColor: UIColor(hex: 0xFFD54A),
                .strokeColor: UIColor(hex: 0x5A3A00), .strokeWidth: -7])
            UIGraphicsPopContext()
        }
        if labelCache.count > 300 { labelCache.removeAll() }
        labelCache[text] = img
        return img
    }

    static let bubbleBlocked = bubble(symbol: "!", color: UIColor(hex: 0xF59E0B))
    static let bubbleWaiting = bubble(symbol: "?", color: UIColor(hex: 0x64748B))

    static let coin: UIImage = render(64, 64) { c in
        let colors = [UIColor(hex: 0xFFE27A).cgColor, UIColor(hex: 0xD99A1E).cgColor] as CFArray
        let locs: [CGFloat] = [0, 1]
        c.addEllipse(in: CGRect(x: 2, y: 2, width: 60, height: 60))
        c.clip()
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) {
            c.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 64, y: 64), options: [])
        }
        c.resetClip()
        c.setStrokeColor(UIColor(hex: 0x9A6A10).cgColor)
        c.setLineWidth(3)
        c.strokeEllipse(in: CGRect(x: 9, y: 9, width: 46, height: 46))
        UIGraphicsPushContext(c)
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        ("$" as NSString).draw(in: CGRect(x: 0, y: 10, width: 64, height: 44),
                               withAttributes: [.font: roundedFont(34, .black), .foregroundColor: UIColor(hex: 0x7A4E06), .paragraphStyle: p])
        UIGraphicsPopContext()
    }
}

// MARK: - Particle effects

enum Effects {
    static func smoke() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = Tex.softCircle
        ps.birthRate = 0
        ps.particleLifeSpan = 2.4
        ps.particleLifeSpanVariation = 0.6
        ps.particleSize = 0.09
        ps.particleSizeVariation = 0.03
        ps.particleVelocity = 0.38
        ps.particleVelocityVariation = 0.12
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.spreadingAngle = 14
        ps.acceleration = SCNVector3(0.12, 0.02, 0.05)
        ps.particleColor = UIColor(white: 0.9, alpha: 1)
        ps.particleColorVariation = SCNVector4(0, 0, 0.08, 0)
        ps.blendMode = .alpha
        ps.isLightingEnabled = false
        ps.sortingMode = .distance

        let size = CAKeyframeAnimation()
        size.values = [NSNumber(value: 0.1), NSNumber(value: 0.32), NSNumber(value: 0.5)]
        let fade = CAKeyframeAnimation()
        fade.values = [NSNumber(value: 0.0), NSNumber(value: 0.55), NSNumber(value: 0.0)]
        fade.keyTimes = [0, 0.15, 1]
        ps.propertyControllers = [
            .size: SCNParticlePropertyController(animation: size),
            .opacity: SCNParticlePropertyController(animation: fade),
        ]
        return ps
    }

    static func burst(color: UIColor, count: CGFloat, speed: CGFloat, size: CGFloat, life: CGFloat,
                      gravity: Bool, additive: Bool, image: UIImage = Tex.softCircle) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = image
        ps.loops = false
        ps.birthRate = count * 20
        ps.emissionDuration = 0.05
        ps.particleLifeSpan = life
        ps.particleLifeSpanVariation = life * 0.3
        ps.particleSize = size
        ps.particleSizeVariation = size * 0.4
        ps.particleVelocity = speed
        ps.particleVelocityVariation = speed * 0.5
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.spreadingAngle = 70
        ps.particleColor = color
        ps.blendMode = additive ? .additive : .alpha
        ps.isLightingEnabled = false
        if gravity {
            ps.isAffectedByGravity = false
            ps.acceleration = SCNVector3(0, -4.5, 0)
        }
        let fade = CAKeyframeAnimation()
        fade.values = [NSNumber(value: 1.0), NSNumber(value: 1.0), NSNumber(value: 0.0)]
        fade.keyTimes = [0, 0.6, 1]
        ps.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
        return ps
    }

    static func dust() -> SCNParticleSystem {
        let ps = burst(color: UIColor(hex: 0xD8C7A6), count: 18, speed: 1.1, size: 0.16, life: 0.7,
                       gravity: false, additive: false)
        ps.spreadingAngle = 88
        ps.emitterShape = SCNBox(width: 0.8, height: 0.05, length: 0.8, chamferRadius: 0)
        let size = CAKeyframeAnimation()
        size.values = [NSNumber(value: 0.12), NSNumber(value: 0.38)]
        let fade = CAKeyframeAnimation()
        fade.values = [NSNumber(value: 0.7), NSNumber(value: 0.0)]
        ps.propertyControllers = [
            .size: SCNParticlePropertyController(animation: size),
            .opacity: SCNParticlePropertyController(animation: fade),
        ]
        ps.particleColorVariation = SCNVector4(0, 0, 0.1, 0)
        return ps
    }

    static func sparkle() -> SCNParticleSystem {
        let ps = burst(color: UIColor(hex: 0xFFD45A), count: 30, speed: 2.6, size: 0.14, life: 0.9,
                       gravity: true, additive: true, image: Tex.spark)
        ps.spreadingAngle = 40
        return ps
    }

    static func coins() -> SCNParticleSystem {
        let ps = burst(color: UIColor(hex: 0xFFD45A), count: 7, speed: 2.0, size: 0.08, life: 0.6,
                       gravity: true, additive: true, image: Tex.spark)
        ps.spreadingAngle = 25
        return ps
    }
}
