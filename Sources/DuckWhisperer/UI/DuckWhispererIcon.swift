import AppKit

enum DuckWhispererIcon {
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { rect in
            drawDuckWhispererMark(in: rect)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawDuckWhispererMark(in rect: NSRect) {
        let w = rect.width
        let h = rect.height

        NSColor.clear.setFill()
        rect.fill()

        let waveColor = NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.12, alpha: 0.95)
        drawWaveBars(x: w * 0.22, centerY: h * 0.49, scale: w, color: waveColor)
        drawWaveBars(x: w * 0.82, centerY: h * 0.49, scale: w, color: waveColor)

        drawDuckBody(in: rect)
        drawDuckHead(in: rect)
    }

    private static func drawWaveBars(x: CGFloat, centerY: CGFloat, scale: CGFloat, color: NSColor) {
        let heights: [CGFloat] = [0.24, 0.38, 0.28]
        for (index, heightRatio) in heights.enumerated() {
            let barWidth = max(1.0, scale * 0.045)
            let barHeight = scale * heightRatio
            let barX = x + CGFloat(index - 1) * scale * 0.075 - barWidth / 2
            let rect = NSRect(x: barX, y: centerY - barHeight / 2, width: barWidth, height: barHeight)
            let bar = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
            color.withAlphaComponent(0.58 + CGFloat(index == 1 ? 0.32 : 0.12)).setFill()
            bar.fill()
        }
    }

    private static func drawDuckBody(in rect: NSRect) {
        let w = rect.width
        let h = rect.height

        let ground = NSBezierPath(ovalIn: NSRect(x: w * 0.34, y: h * 0.10, width: w * 0.34, height: h * 0.08))
        NSColor.black.withAlphaComponent(0.18).setFill()
        ground.fill()

        drawFoot(origin: NSPoint(x: w * 0.43, y: h * 0.15), width: w * 0.16, height: h * 0.05)
        drawFoot(origin: NSPoint(x: w * 0.54, y: h * 0.15), width: w * 0.17, height: h * 0.05)

        let raisedWing = NSBezierPath()
        raisedWing.move(to: NSPoint(x: w * 0.58, y: h * 0.42))
        raisedWing.curve(
            to: NSPoint(x: w * 0.86, y: h * 0.63),
            controlPoint1: NSPoint(x: w * 0.67, y: h * 0.52),
            controlPoint2: NSPoint(x: w * 0.77, y: h * 0.58)
        )
        raisedWing.curve(
            to: NSPoint(x: w * 0.72, y: h * 0.39),
            controlPoint1: NSPoint(x: w * 0.88, y: h * 0.49),
            controlPoint2: NSPoint(x: w * 0.82, y: h * 0.40)
        )
        raisedWing.curve(
            to: NSPoint(x: w * 0.58, y: h * 0.42),
            controlPoint1: NSPoint(x: w * 0.67, y: h * 0.39),
            controlPoint2: NSPoint(x: w * 0.62, y: h * 0.40)
        )
        raisedWing.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.70, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.16, alpha: 1)
        ])?.draw(in: raisedWing, angle: 60)

        let body = NSBezierPath()
        body.move(to: NSPoint(x: w * 0.33, y: h * 0.34))
        body.curve(
            to: NSPoint(x: w * 0.47, y: h * 0.19),
            controlPoint1: NSPoint(x: w * 0.34, y: h * 0.24),
            controlPoint2: NSPoint(x: w * 0.39, y: h * 0.19)
        )
        body.curve(
            to: NSPoint(x: w * 0.69, y: h * 0.36),
            controlPoint1: NSPoint(x: w * 0.61, y: h * 0.18),
            controlPoint2: NSPoint(x: w * 0.70, y: h * 0.26)
        )
        body.curve(
            to: NSPoint(x: w * 0.58, y: h * 0.54),
            controlPoint1: NSPoint(x: w * 0.68, y: h * 0.48),
            controlPoint2: NSPoint(x: w * 0.63, y: h * 0.54)
        )
        body.curve(
            to: NSPoint(x: w * 0.33, y: h * 0.34),
            controlPoint1: NSPoint(x: w * 0.42, y: h * 0.54),
            controlPoint2: NSPoint(x: w * 0.32, y: h * 0.46)
        )
        body.close()
        NSGradient(colors: [
            NSColor.white,
            NSColor(calibratedRed: 0.98, green: 0.86, blue: 0.54, alpha: 1)
        ])?.draw(in: body, angle: 90)

        let wing = NSBezierPath()
        wing.move(to: NSPoint(x: w * 0.43, y: h * 0.36))
        wing.curve(
            to: NSPoint(x: w * 0.58, y: h * 0.34),
            controlPoint1: NSPoint(x: w * 0.48, y: h * 0.43),
            controlPoint2: NSPoint(x: w * 0.55, y: h * 0.42)
        )
        wing.curve(
            to: NSPoint(x: w * 0.47, y: h * 0.27),
            controlPoint1: NSPoint(x: w * 0.56, y: h * 0.28),
            controlPoint2: NSPoint(x: w * 0.51, y: h * 0.27)
        )
        wing.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.62, alpha: 0.96),
            NSColor(calibratedRed: 0.98, green: 0.68, blue: 0.14, alpha: 0.96)
        ])?.draw(in: wing, angle: 90)

        drawBowTie(center: NSPoint(x: w * 0.58, y: h * 0.51), scale: w * 0.10)
    }

    private static func drawDuckHead(in rect: NSRect) {
        let w = rect.width
        let h = rect.height

        let neck = NSBezierPath()
        neck.move(to: NSPoint(x: w * 0.53, y: h * 0.48))
        neck.curve(
            to: NSPoint(x: w * 0.54, y: h * 0.69),
            controlPoint1: NSPoint(x: w * 0.53, y: h * 0.56),
            controlPoint2: NSPoint(x: w * 0.52, y: h * 0.64)
        )
        neck.curve(
            to: NSPoint(x: w * 0.66, y: h * 0.69),
            controlPoint1: NSPoint(x: w * 0.57, y: h * 0.73),
            controlPoint2: NSPoint(x: w * 0.62, y: h * 0.73)
        )
        neck.curve(
            to: NSPoint(x: w * 0.63, y: h * 0.48),
            controlPoint1: NSPoint(x: w * 0.67, y: h * 0.61),
            controlPoint2: NSPoint(x: w * 0.66, y: h * 0.54)
        )
        neck.close()
        NSGradient(colors: [
            NSColor.white,
            NSColor(calibratedRed: 0.99, green: 0.86, blue: 0.52, alpha: 1)
        ])?.draw(in: neck, angle: 90)

        let head = NSBezierPath(ovalIn: NSRect(x: w * 0.52, y: h * 0.67, width: w * 0.24, height: h * 0.21))
        NSGradient(colors: [
            NSColor.white,
            NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.48, alpha: 1)
        ])?.draw(in: head, angle: 80)

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: w * 0.73, y: h * 0.75))
        beak.curve(
            to: NSPoint(x: w * 0.90, y: h * 0.72),
            controlPoint1: NSPoint(x: w * 0.80, y: h * 0.79),
            controlPoint2: NSPoint(x: w * 0.87, y: h * 0.77)
        )
        beak.curve(
            to: NSPoint(x: w * 0.73, y: h * 0.68),
            controlPoint1: NSPoint(x: w * 0.86, y: h * 0.66),
            controlPoint2: NSPoint(x: w * 0.79, y: h * 0.65)
        )
        beak.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.67, blue: 0.10, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.02, alpha: 1)
        ])?.draw(in: beak, angle: 0)

        let eye = NSBezierPath(ovalIn: NSRect(x: w * 0.62, y: h * 0.76, width: w * 0.055, height: h * 0.070))
        NSColor(calibratedWhite: 0.04, alpha: 1).setFill()
        eye.fill()

        let glint = NSBezierPath(ovalIn: NSRect(x: w * 0.637, y: h * 0.795, width: w * 0.016, height: h * 0.016))
        NSColor.white.withAlphaComponent(0.92).setFill()
        glint.fill()
    }

    private static func drawFoot(origin: NSPoint, width: CGFloat, height: CGFloat) {
        let foot = NSBezierPath()
        foot.move(to: origin)
        foot.curve(
            to: NSPoint(x: origin.x + width, y: origin.y),
            controlPoint1: NSPoint(x: origin.x + width * 0.30, y: origin.y + height),
            controlPoint2: NSPoint(x: origin.x + width * 0.72, y: origin.y + height * 0.82)
        )
        foot.curve(
            to: origin,
            controlPoint1: NSPoint(x: origin.x + width * 0.70, y: origin.y - height * 0.55),
            controlPoint2: NSPoint(x: origin.x + width * 0.23, y: origin.y - height * 0.45)
        )
        foot.close()
        NSColor(calibratedRed: 1.0, green: 0.58, blue: 0.05, alpha: 1).setFill()
        foot.fill()
    }

    private static func drawBowTie(center: NSPoint, scale: CGFloat) {
        let left = NSBezierPath()
        left.move(to: center)
        left.line(to: NSPoint(x: center.x - scale * 0.85, y: center.y + scale * 0.42))
        left.line(to: NSPoint(x: center.x - scale * 0.86, y: center.y - scale * 0.42))
        left.close()

        let right = NSBezierPath()
        right.move(to: center)
        right.line(to: NSPoint(x: center.x + scale * 0.85, y: center.y + scale * 0.42))
        right.line(to: NSPoint(x: center.x + scale * 0.86, y: center.y - scale * 0.42))
        right.close()

        NSColor(calibratedRed: 1.0, green: 0.63, blue: 0.08, alpha: 1).setFill()
        left.fill()
        right.fill()

        let knot = NSBezierPath(ovalIn: NSRect(x: center.x - scale * 0.22, y: center.y - scale * 0.20, width: scale * 0.44, height: scale * 0.40))
        NSColor(calibratedRed: 0.88, green: 0.39, blue: 0.02, alpha: 1).setFill()
        knot.fill()
    }
}
