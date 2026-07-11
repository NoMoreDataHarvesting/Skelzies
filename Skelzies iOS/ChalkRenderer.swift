import SpriteKit
import UIKit

/// Deterministic RNG so the chalk wobble is identical every launch.
struct ChalkRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

enum ChalkRenderer {

    static let chalk = UIColor(white: 0.95, alpha: 1)

    // MARK: - Full-scene texture (asphalt + chalk board + Start)

    static func boardTexture() -> SKTexture {
        let size = Layout.sceneSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { rc in
            let ctx = rc.cgContext
            var rng = ChalkRNG(state: 0xC0FFEE)
            drawAsphalt(ctx, size: size, rng: &rng)
            drawBoard(ctx, rng: &rng)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private static func drawAsphalt(_ ctx: CGContext, size: CGSize, rng: inout ChalkRNG) {
        ctx.setFillColor(UIColor(rgb: 0x232428).cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        // Street-lamp vignette
        let colors = [UIColor(white: 1, alpha: 0.05).cgColor,
                      UIColor(white: 0, alpha: 0.30).cgColor] as CFArray
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            ctx.drawRadialGradient(grad, startCenter: center, startRadius: 120,
                                   endCenter: center, endRadius: 760,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // Aggregate speckle
        for _ in 0..<16000 {
            let x = CGFloat(Double.random(in: 0...1, using: &rng)) * size.width
            let y = CGFloat(Double.random(in: 0...1, using: &rng)) * size.height
            let light = Double.random(in: 0...1, using: &rng) > 0.5
            let a = CGFloat(Double.random(in: 0...1, using: &rng))
            ctx.setFillColor(light ? UIColor(white: 1, alpha: 0.02 + a * 0.05).cgColor
                                   : UIColor(white: 0, alpha: 0.05 + a * 0.13).cgColor)
            let s: CGFloat = Double.random(in: 0...1, using: &rng) < 0.08 ? 2 : 1
            ctx.fill(CGRect(x: x, y: y, width: s, height: 1))
        }

        // A few tar cracks
        ctx.setStrokeColor(UIColor(white: 0, alpha: 0.30).cgColor)
        ctx.setLineWidth(1.6)
        ctx.setLineCap(.round)
        for _ in 0..<4 {
            var x = CGFloat(Double.random(in: 0...1, using: &rng)) * size.width
            var y = CGFloat(Double.random(in: 0...1, using: &rng)) * size.height
            ctx.beginPath()
            ctx.move(to: CGPoint(x: x, y: y))
            for _ in 0..<7 {
                x += CGFloat(Double.random(in: -1...1, using: &rng)) * 55
                y += CGFloat(Double.random(in: -1...1, using: &rng)) * 55
                ctx.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.strokePath()
        }
    }

    private static func drawBoard(_ ctx: CGContext, rng: inout ChalkRNG) {
        // Outer chalk square
        chalkRect(ctx, Layout.boardRect, width: 3.6, alpha: 0.9, rng: &rng)

        // Numbered boxes with outward-facing digits
        for box in Layout.boxes {
            chalkRect(ctx, box.rect, width: 3.0, alpha: 0.88, rng: &rng)
            let fontSize: CGFloat = box.n == 13 ? 38 : (box.rect.width > 80 ? 46 : 34)
            drawChalkText(ctx, "\(box.n)",
                          at: CGPoint(x: box.rect.midX, y: box.rect.midY),
                          size: fontSize, rotation: box.rotation)
        }

        // Dead-zone frame + the four "tunnel" diagonals
        chalkRect(ctx, Layout.deadFrameRect, width: 2.8, alpha: 0.85, rng: &rng)
        let f = Layout.deadFrameRect, t = Layout.box13Rect
        chalkLine(ctx, from: CGPoint(x: f.minX, y: f.minY), to: CGPoint(x: t.minX, y: t.minY), width: 2.6, rng: &rng)
        chalkLine(ctx, from: CGPoint(x: f.maxX, y: f.minY), to: CGPoint(x: t.maxX, y: t.minY), width: 2.6, rng: &rng)
        chalkLine(ctx, from: CGPoint(x: f.maxX, y: f.maxY), to: CGPoint(x: t.maxX, y: t.maxY), width: 2.6, rng: &rng)
        chalkLine(ctx, from: CGPoint(x: f.minX, y: f.maxY), to: CGPoint(x: t.minX, y: t.maxY), width: 2.6, rng: &rng)

        // Faint hatch inside the dead zone
        ctx.saveGState()
        let clip = CGMutablePath()
        clip.addRect(f)
        clip.addRect(t)
        ctx.addPath(clip)
        ctx.clip(using: .evenOdd)
        var x = f.minX - f.height
        while x < f.maxX {
            chalkLine(ctx, from: CGPoint(x: x, y: f.minY),
                      to: CGPoint(x: x + f.height, y: f.maxY),
                      width: 1.3, alpha: 0.20, wobble: 1.0, rng: &rng)
            x += 16
        }
        ctx.restoreGState()

        // "Start" — written vertically off the top-left corner, like the photo
        drawChalkText(ctx, "Start", at: CGPoint(x: 130, y: 140), size: 26, rotation: -.pi / 2)
        chalkLine(ctx, from: CGPoint(x: 148, y: 100), to: CGPoint(x: 148, y: 182), width: 2.4, alpha: 0.8, rng: &rng)
    }

    // MARK: - Chalk primitives

    static func chalkLine(_ ctx: CGContext, from a: CGPoint, to b: CGPoint,
                          width: CGFloat = 3, color: UIColor = chalk,
                          alpha: CGFloat = 0.85, wobble: CGFloat = 1.6,
                          rng: inout ChalkRNG) {
        let len = hypot(b.x - a.x, b.y - a.y)
        let steps = max(2, Int(len / 14))
        for pass in 0..<2 {
            let w = pass == 0 ? width : width * 0.55
            let al = pass == 0 ? alpha * 0.6 : alpha * 0.9
            ctx.setStrokeColor(color.withAlphaComponent(al).cgColor)
            ctx.setLineWidth(w)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.beginPath()
            ctx.move(to: jitter(a, wobble, &rng))
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                ctx.addLine(to: jitter(p, wobble, &rng))
            }
            ctx.strokePath()
        }
    }

    static func chalkRect(_ ctx: CGContext, _ r: CGRect, width: CGFloat = 3,
                          alpha: CGFloat = 0.85, rng: inout ChalkRNG) {
        chalkLine(ctx, from: CGPoint(x: r.minX, y: r.minY), to: CGPoint(x: r.maxX, y: r.minY), width: width, alpha: alpha, rng: &rng)
        chalkLine(ctx, from: CGPoint(x: r.maxX, y: r.minY), to: CGPoint(x: r.maxX, y: r.maxY), width: width, alpha: alpha, rng: &rng)
        chalkLine(ctx, from: CGPoint(x: r.maxX, y: r.maxY), to: CGPoint(x: r.minX, y: r.maxY), width: width, alpha: alpha, rng: &rng)
        chalkLine(ctx, from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.minX, y: r.minY), width: width, alpha: alpha, rng: &rng)
    }

    private static func jitter(_ p: CGPoint, _ w: CGFloat, _ rng: inout ChalkRNG) -> CGPoint {
        CGPoint(x: p.x + CGFloat(Double.random(in: -1...1, using: &rng)) * w * 0.5,
                y: p.y + CGFloat(Double.random(in: -1...1, using: &rng)) * w * 0.5)
    }

    static func drawChalkText(_ ctx: CGContext, _ text: String, at p: CGPoint,
                              size: CGFloat, rotation: CGFloat, color: UIColor = chalk) {
        let font = UIFont(name: "ChalkboardSE-Bold", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .bold)
        let string = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color.withAlphaComponent(0.92),
        ])
        let shadow = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor(white: 0, alpha: 0.4),
        ])
        let sz = string.size()
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: rotation)
        shadow.draw(at: CGPoint(x: -sz.width / 2 + 1.5, y: -sz.height / 2 + 1.5))
        string.draw(at: CGPoint(x: -sz.width / 2, y: -sz.height / 2))
        ctx.restoreGState()
    }

    // MARK: - Bottle-cap texture

    static func capTexture(colorIndex i: Int) -> SKTexture {
        let d: CGFloat = 44
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: CGSize(width: d, height: d), format: format).image { rc in
            let ctx = rc.cgContext
            let c = CGPoint(x: d / 2, y: d / 2)
            let R: CGFloat = d / 2 - 2

            // Fluted rim
            ctx.setFillColor(CapPalette.dark[i % 6].cgColor)
            let rim = CGMutablePath()
            let teeth = 22
            for k in 0...teeth {
                let a = CGFloat(k) / CGFloat(teeth) * 2 * .pi
                let r = R + (k % 2 == 0 ? 0 : -1.8)
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                k == 0 ? rim.move(to: p) : rim.addLine(to: p)
            }
            rim.closeSubpath()
            ctx.addPath(rim)
            ctx.fillPath()

            // Body gradient
            let colors = [CapPalette.hi[i % 6].cgColor,
                          CapPalette.base[i % 6].cgColor,
                          CapPalette.dark[i % 6].cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1]) {
                ctx.saveGState()
                ctx.addEllipse(in: CGRect(x: c.x - (R - 2), y: c.y - (R - 2), width: (R - 2) * 2, height: (R - 2) * 2))
                ctx.clip()
                ctx.drawRadialGradient(grad,
                                       startCenter: CGPoint(x: c.x - 5, y: c.y - 6), startRadius: 1,
                                       endCenter: c, endRadius: R,
                                       options: .drawsAfterEndLocation)
                ctx.restoreGState()
            }

            // Wax fill
            let waxRect = CGRect(x: c.x - R * 0.55, y: c.y - R * 0.55, width: R * 1.1, height: R * 1.1)
            ctx.setFillColor(UIColor(white: 1, alpha: 0.18).cgColor)
            ctx.fillEllipse(in: waxRect)
            ctx.setStrokeColor(UIColor(white: 0, alpha: 0.25).cgColor)
            ctx.setLineWidth(1)
            ctx.strokeEllipse(in: waxRect)

            // Gloss
            ctx.setStrokeColor(UIColor(white: 1, alpha: 0.55).cgColor)
            ctx.setLineWidth(2.2)
            ctx.setLineCap(.round)
            ctx.addArc(center: CGPoint(x: c.x - 3, y: c.y - 4), radius: R * 0.6,
                       startAngle: -2.4, endAngle: -1.2, clockwise: false)
            ctx.strokePath()
        }
        return SKTexture(image: image)
    }
}
