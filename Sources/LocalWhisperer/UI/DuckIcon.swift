import AppKit

enum DuckIcon {
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            drawDuckSilhouette(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawDuckSilhouette(in rect: NSRect) {
        let w = rect.width
        let h = rect.height
        NSColor.black.setFill()

        NSBezierPath(ovalIn: NSRect(x: w * 0.10, y: h * 0.28, width: w * 0.58, height: h * 0.38)).fill()
        NSBezierPath(ovalIn: NSRect(x: w * 0.56, y: h * 0.54, width: w * 0.28, height: h * 0.28)).fill()

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: w * 0.80, y: h * 0.66))
        beak.line(to: NSPoint(x: w * 0.98, y: h * 0.61))
        beak.line(to: NSPoint(x: w * 0.80, y: h * 0.56))
        beak.close()
        beak.fill()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: w * 0.15, y: h * 0.49))
        tail.line(to: NSPoint(x: w * 0.01, y: h * 0.61))
        tail.line(to: NSPoint(x: w * 0.05, y: h * 0.43))
        tail.close()
        tail.fill()

        let water = NSBezierPath(roundedRect: NSRect(x: w * 0.12, y: h * 0.14, width: w * 0.70, height: h * 0.10), xRadius: h * 0.05, yRadius: h * 0.05)
        water.fill()
    }
}
