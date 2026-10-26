import SceneKit
import UIKit

// MARK: - Particle effects

enum Effects {
    static func steam() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = Tex.softCircle
        ps.birthRate = 0
        ps.particleLifeSpan = 1.6
        ps.particleLifeSpanVariation = 0.4
        ps.particleSize = 0.08
        ps.particleSizeVariation = 0.03
        ps.particleVelocity = 0.45
        ps.particleVelocityVariation = 0.15
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.spreadingAngle = 12
        ps.acceleration = SCNVector3(0.05, 0.05, 0.08)
        ps.particleColor = UIColor(white: 0.97, alpha: 1)
        ps.blendMode = .alpha
        ps.isLightingEnabled = false
        ps.sortingMode = .none
        let size = CAKeyframeAnimation()
        size.values = [NSNumber(value: 0.08), NSNumber(value: 0.26), NSNumber(value: 0.42)]
        let fade = CAKeyframeAnimation()
        fade.values = [NSNumber(value: 0.0), NSNumber(value: 0.5), NSNumber(value: 0.0)]
        fade.keyTimes = [0, 0.2, 1]
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

    static func sparkle() -> SCNParticleSystem {
        let ps = burst(color: UIColor(hex: 0xFFD45A), count: 30, speed: 2.6, size: 0.16, life: 0.9,
                       gravity: true, additive: true, image: Tex.spark)
        ps.spreadingAngle = 40
        return ps
    }

    static func coins() -> SCNParticleSystem {
        let ps = burst(color: UIColor(hex: 0xFFD45A), count: 8, speed: 2.2, size: 0.1, life: 0.6,
                       gravity: true, additive: true, image: Tex.spark)
        ps.spreadingAngle = 28
        return ps
    }

    static func puff() -> SCNParticleSystem {
        let ps = burst(color: UIColor(white: 0.98, alpha: 1), count: 10, speed: 0.9, size: 0.14, life: 0.5,
                       gravity: false, additive: false)
        ps.spreadingAngle = 60
        return ps
    }

    static func dust() -> SCNParticleSystem {
        let ps = burst(color: UIColor(hex: 0xD8C7A6), count: 22, speed: 1.2, size: 0.2, life: 0.8,
                       gravity: false, additive: false)
        ps.spreadingAngle = 88
        ps.emitterShape = SCNBox(width: 1.6, height: 0.05, length: 0.9, chamferRadius: 0)
        let size = CAKeyframeAnimation()
        size.values = [NSNumber(value: 0.14), NSNumber(value: 0.45)]
        let fade = CAKeyframeAnimation()
        fade.values = [NSNumber(value: 0.7), NSNumber(value: 0.0)]
        ps.propertyControllers = [
            .size: SCNParticlePropertyController(animation: size),
            .opacity: SCNParticlePropertyController(animation: fade),
        ]
        return ps
    }

    static func confetti() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = Tex.confettiPiece
        ps.loops = false
        ps.birthRate = 900
        ps.emissionDuration = 0.12
        ps.particleLifeSpan = 2.4
        ps.particleLifeSpanVariation = 0.6
        ps.particleSize = 0.11
        ps.particleSizeVariation = 0.04
        ps.particleVelocity = 7
        ps.particleVelocityVariation = 2.5
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.spreadingAngle = 35
        ps.acceleration = SCNVector3(0, -6, 0)
        ps.dampingFactor = 1.2
        ps.particleAngularVelocity = 360
        ps.particleAngularVelocityVariation = 300
        ps.particleColor = UIColor(hex: 0xFF5252)
        ps.particleColorVariation = SCNVector4(1, 0.2, 0, 0)
        ps.blendMode = .alpha
        ps.isLightingEnabled = false
        let fade = CAKeyframeAnimation()
        fade.values = [NSNumber(value: 1.0), NSNumber(value: 1.0), NSNumber(value: 0.0)]
        fade.keyTimes = [0, 0.75, 1]
        ps.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
        return ps
    }

    static func rain() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = Tex.raindrop
        ps.birthRate = 0
        ps.particleLifeSpan = 1.0
        ps.particleSize = 0.05
        ps.particleVelocity = 16
        ps.particleVelocityVariation = 2
        ps.emittingDirection = SCNVector3(0.08, -1, 0.05)
        ps.spreadingAngle = 2
        ps.stretchFactor = 0.05
        ps.emitterShape = SCNBox(width: 34, height: 0.1, length: 26, chamferRadius: 0)
        ps.particleColor = UIColor(red: 0.8, green: 0.88, blue: 1, alpha: 0.55)
        ps.blendMode = .alpha
        ps.isLightingEnabled = false
        ps.sortingMode = .none
        return ps
    }

    static func splash() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = Tex.softCircle
        ps.birthRate = 0
        ps.particleLifeSpan = 0.25
        ps.particleSize = 0.05
        ps.particleVelocity = 0.9
        ps.particleVelocityVariation = 0.4
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.spreadingAngle = 60
        ps.acceleration = SCNVector3(0, -5, 0)
        ps.emitterShape = SCNBox(width: 30, height: 0.01, length: 18, chamferRadius: 0)
        ps.particleColor = UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 0.5)
        ps.blendMode = .alpha
        ps.isLightingEnabled = false
        ps.sortingMode = .none
        return ps
    }
}

// MARK: - Extra textures

extension Tex {
    static let confettiPiece: UIImage = render(16, 16) { c in
        c.setFillColor(UIColor.white.cgColor)
        c.fill(CGRect(x: 2, y: 5, width: 12, height: 6))
    }

    /// White square used for UI bars inside the 3D scene.
    static let whitePixel: UIImage = render(4, 4, opaque: true) { c in
        c.setFillColor(UIColor.white.cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    }

    /// Soft elongated glow for car headlight beams on the asphalt.
    static let beam: UIImage = render(128, 64) { c in
        let colors = [UIColor(white: 1, alpha: 0.9).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
        let locs: [CGFloat] = [0, 1]
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) else { return }
        c.saveGState()
        c.translateBy(x: 0, y: 32)
        c.scaleBy(x: 1, y: 0.25)
        c.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 128, options: [])
        c.restoreGState()
    }

    static let ringGlow: UIImage = render(128, 128) { c in
        c.setStrokeColor(UIColor.white.cgColor)
        c.setLineWidth(10)
        c.strokeEllipse(in: CGRect(x: 10, y: 10, width: 108, height: 108))
        c.setStrokeColor(UIColor(white: 1, alpha: 0.35).cgColor)
        c.setLineWidth(20)
        c.strokeEllipse(in: CGRect(x: 10, y: 10, width: 108, height: 108))
    }

    static let vipBadge: UIImage = render(128, 96) { c in
        c.setFillColor(UIColor(hex: 0x4A2E00).cgColor)
        let crown = UIBezierPath()
        crown.move(to: CGPoint(x: 14, y: 82))
        crown.addLine(to: CGPoint(x: 8, y: 22))
        crown.addLine(to: CGPoint(x: 40, y: 50))
        crown.addLine(to: CGPoint(x: 64, y: 8))
        crown.addLine(to: CGPoint(x: 88, y: 50))
        crown.addLine(to: CGPoint(x: 120, y: 22))
        crown.addLine(to: CGPoint(x: 114, y: 82))
        crown.close()
        c.addPath(crown.cgPath)
        c.fillPath()
        c.setFillColor(UIColor(hex: 0xFFC83D).cgColor)
        let inner = UIBezierPath(cgPath: crown.cgPath)
        inner.apply(CGAffineTransform(translationX: -64, y: -50).concatenating(CGAffineTransform(scaleX: 0.84, y: 0.8))
            .concatenating(CGAffineTransform(translationX: 64, y: 50)))
        c.addPath(inner.cgPath)
        c.fillPath()
        c.setFillColor(UIColor(hex: 0xE53935).cgColor)
        c.fillEllipse(in: CGRect(x: 56, y: 52, width: 16, height: 16))
    }

    /// Bubble above the courier: dishes with progress counters.
    static func deliveryBubble(_ needs: [(Dish, Int)], got: [Dish: Int], icons: [String: UIImage]) -> UIImage {
        let n = max(1, needs.count)
        let w = 40 + n * 150, h = 150
        return render(w, h) { c in
            let body = CGRect(x: 6, y: 6, width: w - 12, height: 112)
            let path = UIBezierPath(roundedRect: body, cornerRadius: 34)
            path.move(to: CGPoint(x: CGFloat(w) / 2 - 16, y: body.maxY - 1))
            path.addLine(to: CGPoint(x: CGFloat(w) / 2, y: body.maxY + 24))
            path.addLine(to: CGPoint(x: CGFloat(w) / 2 + 16, y: body.maxY - 1))
            path.close()
            c.setFillColor(UIColor(hex: 0xE8F5E9).cgColor)
            c.addPath(path.cgPath)
            c.fillPath()
            c.setStrokeColor(UIColor(hex: 0x2E7D32).cgColor)
            c.setLineWidth(6)
            c.addPath(UIBezierPath(roundedRect: body, cornerRadius: 34).cgPath)
            c.strokePath()
            UIGraphicsPushContext(c)
            for (k, item) in needs.enumerated() {
                let x = CGFloat(26 + k * 150)
                let r = CGRect(x: x, y: 20, width: 84, height: 84)
                if let icon = icons[item.0.iconKey] {
                    icon.draw(in: r)
                } else {
                    c.setFillColor(UIColor(hex: item.0.hex).cgColor)
                    c.fillEllipse(in: r.insetBy(dx: 14, dy: 14))
                }
                let have = min(item.1, got[item.0, default: 0])
                let done = have >= item.1
                Tex.text("\(have)/\(item.1)", in: CGRect(x: x + 78, y: 38, width: 72, height: 50), font: font(34, .black),
                         color: done ? UIColor(hex: 0x2E7D32) : UIColor(hex: 0x37474F), align: .left)
            }
            UIGraphicsPopContext()
        }
    }

    // MARK: Sky over the day

    private static var skyCache: [Int: UIImage] = [:]

    struct RGB {
        var r, g, b: Double
        init(_ hex: UInt32) {
            r = Double((hex >> 16) & 0xFF) / 255
            g = Double((hex >> 8) & 0xFF) / 255
            b = Double(hex & 0xFF) / 255
        }
        init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
        func mix(_ o: RGB, _ t: Double) -> RGB { RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t) }
        var color: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
    }

    /// Colors of the sky for a night factor (0 day, 0.5 sunset, 1 night) and rain (0...1).
    static func skyColors(_ n: Double, rain: Double) -> (zenith: RGB, mid: RGB, horizon: RGB) {
        let day = (RGB(0x4A90E2), RGB(0x8EC5F2), RGB(0xEAF2F4))
        let dusk = (RGB(0x34407E), RGB(0xC0708A), RGB(0xFFB46A))
        let night = (RGB(0x050A1C), RGB(0x0E1A3A), RGB(0x24345C))
        var z: RGB, m: RGB, h: RGB
        if n < 0.5 {
            let t = n * 2
            z = day.0.mix(dusk.0, t); m = day.1.mix(dusk.1, t); h = day.2.mix(dusk.2, t)
        } else {
            let t = (n - 0.5) * 2
            z = dusk.0.mix(night.0, t); m = dusk.1.mix(night.1, t); h = dusk.2.mix(night.2, t)
        }
        if rain > 0 {
            let grey = RGB(0x7D8792).mix(RGB(0x1A1F28), n)
            z = z.mix(grey, rain * 0.75); m = m.mix(grey, rain * 0.75); h = h.mix(grey.mix(RGB(0xBFC6CC), 1 - n), rain * 0.6)
        }
        return (z, m, h)
    }

    static func skyImage(_ n: Double, rain: Double) -> UIImage {
        let qn = Int((n * 20).rounded()), qr = Int((rain * 4).rounded())
        let key = qn * 10 + qr
        if let img = skyCache[key] { return img }
        let (zen, mid, hor) = skyColors(Double(qn) / 20, rain: Double(qr) / 4)
        let below = hor.mix(RGB(0x3A4048), 0.5)
        let w = 256, h = 128
        var px = [UInt8](repeating: 255, count: w * h * 4)
        let stars = max(0, (Double(qn) / 20 - 0.55) / 0.45) * (1 - Double(qr) / 4)
        for y in 0..<h {
            let v = Double(y) / Double(h - 1)
            let col: RGB
            if v < 0.5 {
                let t = v / 0.5
                col = t < 0.55 ? zen.mix(mid, t / 0.55) : mid.mix(hor, pow((t - 0.55) / 0.45, 1.4))
            } else {
                col = hor.mix(below, min(1, (v - 0.5) / 0.2))
            }
            for x in 0..<w {
                let o = (y * w + x) * 4
                var r = col.r, g = col.g, b = col.b
                if stars > 0, v < 0.47 {
                    let hsh = hash01(x, y, 99)
                    if hsh > 0.993 {
                        let a = stars * Double(hash01(x, y, 7)) * (1 - v * 1.6)
                        r += a; g += a; b += a * 0.9
                    }
                }
                px[o] = UInt8(min(255, max(0, r * 255)))
                px[o + 1] = UInt8(min(255, max(0, g * 255)))
                px[o + 2] = UInt8(min(255, max(0, b * 255)))
            }
        }
        let img = image(width: w, height: h, pixels: px)
        skyCache[key] = img
        return img
    }
}
