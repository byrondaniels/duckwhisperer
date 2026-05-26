import AppKit

enum DuckWhispererIcon {
    private static let selectedArtwork: NSImage? = {
        guard let url = Bundle.main.url(forResource: "DuckWhispererOption3Hud", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

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

        if let selectedArtwork {
            drawImage(selectedArtwork, aspectFillIn: rect)
            return
        }

        drawAudioBars(x: w * 0.16, centerY: h * 0.48, scale: w)
        drawAudioBars(x: w * 0.86, centerY: h * 0.48, scale: w)

        let ringRect = NSRect(x: w * 0.26, y: h * 0.16, width: w * 0.52, height: h * 0.66)
        let ring = NSBezierPath(ovalIn: ringRect)
        NSColor(calibratedRed: 0.95, green: 0.62, blue: 0.08, alpha: 0.30).setFill()
        ring.fill()
        NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.12, alpha: 0.86).setStroke()
        ring.lineWidth = max(1.0, w * 0.055)
        ring.stroke()

        drawNeck(in: rect)
        drawHead(in: rect)
        drawBeak(in: rect)
        drawFace(in: rect)
    }

    private static func drawAudioBars(x: CGFloat, centerY: CGFloat, scale: CGFloat) {
        let color = NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.10, alpha: 0.92)
        let heights: [CGFloat] = [0.22, 0.36, 0.26]
        for (index, heightRatio) in heights.enumerated() {
            let barWidth = max(1.0, scale * 0.040)
            let barHeight = scale * heightRatio
            let barX = x + CGFloat(index - 1) * scale * 0.065 - barWidth / 2
            let bar = NSBezierPath(
                roundedRect: NSRect(x: barX, y: centerY - barHeight / 2, width: barWidth, height: barHeight),
                xRadius: barWidth / 2,
                yRadius: barWidth / 2
            )
            color.withAlphaComponent(index == 1 ? 0.92 : 0.70).setFill()
            bar.fill()
        }
    }

    private static func drawNeck(in rect: NSRect) {
        let w = rect.width
        let h = rect.height

        let neck = NSBezierPath()
        neck.move(to: NSPoint(x: w * 0.44, y: h * 0.20))
        neck.curve(
            to: NSPoint(x: w * 0.48, y: h * 0.61),
            controlPoint1: NSPoint(x: w * 0.36, y: h * 0.32),
            controlPoint2: NSPoint(x: w * 0.37, y: h * 0.52)
        )
        neck.curve(
            to: NSPoint(x: w * 0.68, y: h * 0.54),
            controlPoint1: NSPoint(x: w * 0.55, y: h * 0.67),
            controlPoint2: NSPoint(x: w * 0.65, y: h * 0.63)
        )
        neck.curve(
            to: NSPoint(x: w * 0.61, y: h * 0.20),
            controlPoint1: NSPoint(x: w * 0.69, y: h * 0.39),
            controlPoint2: NSPoint(x: w * 0.65, y: h * 0.27)
        )
        neck.curve(
            to: NSPoint(x: w * 0.44, y: h * 0.20),
            controlPoint1: NSPoint(x: w * 0.57, y: h * 0.11),
            controlPoint2: NSPoint(x: w * 0.48, y: h * 0.12)
        )
        neck.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.91, alpha: 1),
            NSColor(calibratedRed: 0.99, green: 0.83, blue: 0.45, alpha: 1)
        ])?.draw(in: neck, angle: 90)
    }

    private static func drawHead(in rect: NSRect) {
        let w = rect.width
        let h = rect.height

        let head = NSBezierPath(ovalIn: NSRect(x: w * 0.43, y: h * 0.49, width: w * 0.38, height: h * 0.36))
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.91, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.42, alpha: 1)
        ])?.draw(in: head, angle: 80)
    }

    private static func drawBeak(in rect: NSRect) {
        let w = rect.width
        let h = rect.height

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: w * 0.75, y: h * 0.68))
        beak.curve(
            to: NSPoint(x: w * 1.01, y: h * 0.63),
            controlPoint1: NSPoint(x: w * 0.86, y: h * 0.75),
            controlPoint2: NSPoint(x: w * 0.96, y: h * 0.74)
        )
        beak.curve(
            to: NSPoint(x: w * 0.75, y: h * 0.53),
            controlPoint1: NSPoint(x: w * 0.96, y: h * 0.52),
            controlPoint2: NSPoint(x: w * 0.86, y: h * 0.49)
        )
        beak.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.66, blue: 0.10, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.03, alpha: 1)
        ])?.draw(in: beak, angle: 0)
    }

    private static func drawFace(in rect: NSRect) {
        let w = rect.width
        let h = rect.height

        let eye = NSBezierPath(ovalIn: NSRect(x: w * 0.58, y: h * 0.66, width: w * 0.07, height: h * 0.09))
        NSColor(calibratedWhite: 0.04, alpha: 1).setFill()
        eye.fill()

        let glint = NSBezierPath(ovalIn: NSRect(x: w * 0.603, y: h * 0.705, width: w * 0.018, height: h * 0.020))
        NSColor.white.withAlphaComponent(0.92).setFill()
        glint.fill()

        let smile = NSBezierPath()
        smile.lineWidth = max(1.2, w * 0.055)
        smile.lineCapStyle = .round
        smile.move(to: NSPoint(x: w * 0.70, y: h * 0.58))
        smile.curve(
            to: NSPoint(x: w * 0.77, y: h * 0.58),
            controlPoint1: NSPoint(x: w * 0.715, y: h * 0.53),
            controlPoint2: NSPoint(x: w * 0.755, y: h * 0.53)
        )
        NSColor(calibratedWhite: 0.08, alpha: 0.90).setStroke()
        smile.stroke()
    }

    private static func drawImage(_ image: NSImage, aspectFillIn targetRect: NSRect) {
        guard image.size.width > 0, image.size.height > 0 else {
            return
        }

        let sourceSize = image.size
        let scale = max(targetRect.width / sourceSize.width, targetRect.height / sourceSize.height)
        let sourceWidth = targetRect.width / scale
        let sourceHeight = targetRect.height / scale
        let sourceRect = NSRect(
            x: (sourceSize.width - sourceWidth) / 2,
            y: (sourceSize.height - sourceHeight) / 2,
            width: sourceWidth,
            height: sourceHeight
        )
        image.draw(in: targetRect, from: sourceRect, operation: .sourceOver, fraction: 1)
    }
}
