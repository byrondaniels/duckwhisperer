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
        drawWave(center: NSPoint(x: w * 0.38, y: h * 0.47), radius: w * 0.19, leftSide: true, color: waveColor, lineWidth: max(1.4, w * 0.07))
        drawWave(center: NSPoint(x: w * 0.62, y: h * 0.47), radius: w * 0.19, leftSide: false, color: waveColor, lineWidth: max(1.4, w * 0.07))

        let foot = NSBezierPath(ovalIn: NSRect(x: w * 0.45, y: h * 0.08, width: w * 0.10, height: h * 0.16))
        NSColor(calibratedWhite: 0.88, alpha: 0.92).setFill()
        foot.fill()

        let body = NSBezierPath(ovalIn: NSRect(x: w * 0.38, y: h * 0.18, width: w * 0.24, height: h * 0.25))
        NSGradient(colors: [
            NSColor.white,
            NSColor(calibratedWhite: 0.83, alpha: 1)
        ])?.draw(in: body, angle: 90)

        let wing = NSBezierPath()
        wing.lineWidth = max(1.2, w * 0.055)
        wing.lineCapStyle = .round
        wing.move(to: NSPoint(x: w * 0.61, y: h * 0.28))
        wing.curve(
            to: NSPoint(x: w * 0.74, y: h * 0.34),
            controlPoint1: NSPoint(x: w * 0.66, y: h * 0.25),
            controlPoint2: NSPoint(x: w * 0.70, y: h * 0.28)
        )
        NSColor.white.withAlphaComponent(0.95).setStroke()
        wing.stroke()

        drawFeatherHead(in: NSRect(x: w * 0.31, y: h * 0.30, width: w * 0.38, height: h * 0.58))

        let leftEye = NSBezierPath(ovalIn: NSRect(x: w * 0.42, y: h * 0.43, width: w * 0.07, height: h * 0.10))
        let rightEye = NSBezierPath(ovalIn: NSRect(x: w * 0.54, y: h * 0.43, width: w * 0.07, height: h * 0.10))
        NSColor(calibratedWhite: 0.04, alpha: 1).setFill()
        leftEye.fill()
        rightEye.fill()
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

    private static func drawFeatherHead(in rect: NSRect) {
        let x = rect.minX
        let y = rect.minY
        let w = rect.width
        let h = rect.height

        let duckwhisperer = NSBezierPath()
        duckwhisperer.move(to: NSPoint(x: x + w * 0.28, y: y + h * 0.12))
        duckwhisperer.curve(
            to: NSPoint(x: x + w * 0.92, y: y + h * 0.98),
            controlPoint1: NSPoint(x: x + w * 0.30, y: y + h * 0.58),
            controlPoint2: NSPoint(x: x + w * 0.66, y: y + h * 0.88)
        )
        duckwhisperer.curve(
            to: NSPoint(x: x + w * 0.74, y: y + h * 0.25),
            controlPoint1: NSPoint(x: x + w * 0.96, y: y + h * 0.70),
            controlPoint2: NSPoint(x: x + w * 0.94, y: y + h * 0.38)
        )
        duckwhisperer.curve(
            to: NSPoint(x: x + w * 0.28, y: y + h * 0.12),
            controlPoint1: NSPoint(x: x + w * 0.62, y: y + h * 0.08),
            controlPoint2: NSPoint(x: x + w * 0.42, y: y + h * 0.04)
        )
        duckwhisperer.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.62, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.67, blue: 0.08, alpha: 1)
        ])?.draw(in: duckwhisperer, angle: 120)

        let face = NSBezierPath(ovalIn: NSRect(x: x + w * 0.16, y: y, width: w * 0.62, height: h * 0.45))
        NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.16, alpha: 1).setFill()
        face.fill()
    }
}
