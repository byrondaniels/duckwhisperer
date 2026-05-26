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
        drawWave(center: NSPoint(x: w * 0.30, y: h * 0.48), radius: w * 0.17, leftSide: true, color: waveColor, lineWidth: max(1.2, w * 0.055))
        drawWave(center: NSPoint(x: w * 0.73, y: h * 0.48), radius: w * 0.17, leftSide: false, color: waveColor, lineWidth: max(1.2, w * 0.055))

        drawDuckBody(in: rect)
        drawDuckHead(in: rect)
    }

    private static func drawWave(center: NSPoint, radius: CGFloat, leftSide: Bool, color: NSColor, lineWidth: CGFloat) {
        let sign: CGFloat = leftSide ? -1 : 1
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: center.x + sign * radius * 0.35, y: center.y + radius * 0.70))
        path.curve(
            to: NSPoint(x: center.x + sign * radius * 0.35, y: center.y - radius * 0.70),
            controlPoint1: NSPoint(x: center.x + sign * radius, y: center.y + radius * 0.45),
            controlPoint2: NSPoint(x: center.x + sign * radius, y: center.y - radius * 0.45)
        )
        color.setStroke()
        path.stroke()
    }

    private static func drawDuckBody(in rect: NSRect) {
        let w = rect.width
        let h = rect.height

        let body = NSBezierPath()
        body.move(to: NSPoint(x: w * 0.20, y: h * 0.36))
        body.curve(
            to: NSPoint(x: w * 0.43, y: h * 0.18),
            controlPoint1: NSPoint(x: w * 0.22, y: h * 0.24),
            controlPoint2: NSPoint(x: w * 0.31, y: h * 0.18)
        )
        body.curve(
            to: NSPoint(x: w * 0.73, y: h * 0.38),
            controlPoint1: NSPoint(x: w * 0.61, y: h * 0.18),
            controlPoint2: NSPoint(x: w * 0.73, y: h * 0.25)
        )
        body.curve(
            to: NSPoint(x: w * 0.48, y: h * 0.53),
            controlPoint1: NSPoint(x: w * 0.73, y: h * 0.50),
            controlPoint2: NSPoint(x: w * 0.61, y: h * 0.55)
        )
        body.curve(
            to: NSPoint(x: w * 0.20, y: h * 0.36),
            controlPoint1: NSPoint(x: w * 0.32, y: h * 0.54),
            controlPoint2: NSPoint(x: w * 0.22, y: h * 0.48)
        )
        body.close()
        NSGradient(colors: [
            NSColor.white,
            NSColor(calibratedWhite: 0.82, alpha: 1)
        ])?.draw(in: body, angle: 90)

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: w * 0.22, y: h * 0.40))
        tail.line(to: NSPoint(x: w * 0.08, y: h * 0.53))
        tail.line(to: NSPoint(x: w * 0.16, y: h * 0.32))
        tail.close()
        NSColor.white.withAlphaComponent(0.96).setFill()
        tail.fill()

        let wing = NSBezierPath()
        wing.move(to: NSPoint(x: w * 0.39, y: h * 0.37))
        wing.curve(
            to: NSPoint(x: w * 0.56, y: h * 0.34),
            controlPoint1: NSPoint(x: w * 0.45, y: h * 0.43),
            controlPoint2: NSPoint(x: w * 0.52, y: h * 0.42)
        )
        wing.curve(
            to: NSPoint(x: w * 0.43, y: h * 0.28),
            controlPoint1: NSPoint(x: w * 0.54, y: h * 0.29),
            controlPoint2: NSPoint(x: w * 0.48, y: h * 0.27)
        )
        wing.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.62, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.67, blue: 0.08, alpha: 1)
        ])?.draw(in: wing, angle: 90)
    }

    private static func drawDuckHead(in rect: NSRect) {
        let w = rect.width
        let h = rect.height

        let neck = NSBezierPath(ovalIn: NSRect(x: w * 0.56, y: h * 0.42, width: w * 0.18, height: h * 0.28))
        NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.13, alpha: 1).setFill()
        neck.fill()

        let head = NSBezierPath(ovalIn: NSRect(x: w * 0.54, y: h * 0.58, width: w * 0.28, height: h * 0.24))
        NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.16, alpha: 1).setFill()
        head.fill()

        let crest = NSBezierPath()
        crest.move(to: NSPoint(x: w * 0.61, y: h * 0.76))
        crest.curve(
            to: NSPoint(x: w * 0.55, y: h * 0.92),
            controlPoint1: NSPoint(x: w * 0.57, y: h * 0.82),
            controlPoint2: NSPoint(x: w * 0.56, y: h * 0.88)
        )
        crest.curve(
            to: NSPoint(x: w * 0.70, y: h * 0.78),
            controlPoint1: NSPoint(x: w * 0.66, y: h * 0.89),
            controlPoint2: NSPoint(x: w * 0.70, y: h * 0.84)
        )
        crest.close()
        NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.24, alpha: 1).setFill()
        crest.fill()

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: w * 0.78, y: h * 0.68))
        beak.curve(
            to: NSPoint(x: w * 0.95, y: h * 0.63),
            controlPoint1: NSPoint(x: w * 0.85, y: h * 0.71),
            controlPoint2: NSPoint(x: w * 0.91, y: h * 0.68)
        )
        beak.curve(
            to: NSPoint(x: w * 0.78, y: h * 0.58),
            controlPoint1: NSPoint(x: w * 0.91, y: h * 0.57),
            controlPoint2: NSPoint(x: w * 0.84, y: h * 0.56)
        )
        beak.close()
        NSColor(calibratedRed: 1.0, green: 0.50, blue: 0.05, alpha: 1).setFill()
        beak.fill()

        let eye = NSBezierPath(ovalIn: NSRect(x: w * 0.66, y: h * 0.68, width: w * 0.07, height: h * 0.085))
        NSColor(calibratedWhite: 0.04, alpha: 1).setFill()
        eye.fill()

        let glint = NSBezierPath(ovalIn: NSRect(x: w * 0.68, y: h * 0.72, width: w * 0.018, height: h * 0.018))
        NSColor.white.withAlphaComponent(0.92).setFill()
        glint.fill()
    }
}
