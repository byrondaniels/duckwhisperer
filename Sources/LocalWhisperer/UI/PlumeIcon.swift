import AppKit

enum PlumeIcon {
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            drawPlumeMark(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawPlumeMark(in rect: NSRect) {
        let w = rect.width
        let h = rect.height
        NSColor.black.setFill()

        let feather = NSBezierPath()
        feather.move(to: NSPoint(x: w * 0.20, y: h * 0.78))
        feather.curve(
            to: NSPoint(x: w * 0.80, y: h * 0.14),
            controlPoint1: NSPoint(x: w * 0.26, y: h * 0.26),
            controlPoint2: NSPoint(x: w * 0.68, y: h * 0.08)
        )
        feather.curve(
            to: NSPoint(x: w * 0.28, y: h * 0.86),
            controlPoint1: NSPoint(x: w * 0.45, y: h * 0.18),
            controlPoint2: NSPoint(x: w * 0.18, y: h * 0.52)
        )
        feather.curve(
            to: NSPoint(x: w * 0.20, y: h * 0.78),
            controlPoint1: NSPoint(x: w * 0.25, y: h * 0.86),
            controlPoint2: NSPoint(x: w * 0.22, y: h * 0.82)
        )
        feather.close()
        feather.fill()

        let notch = NSBezierPath()
        notch.move(to: NSPoint(x: w * 0.43, y: h * 0.63))
        notch.line(to: NSPoint(x: w * 0.18, y: h * 0.56))
        notch.line(to: NSPoint(x: w * 0.46, y: h * 0.53))
        notch.close()
        NSColor.clear.setFill()
        notch.fill()

        let stem = NSBezierPath()
        stem.lineWidth = max(1.4, w * 0.09)
        stem.lineCapStyle = .round
        stem.move(to: NSPoint(x: w * 0.26, y: h * 0.82))
        stem.line(to: NSPoint(x: w * 0.78, y: h * 0.16))
        NSColor.black.setStroke()
        stem.stroke()
    }
}
