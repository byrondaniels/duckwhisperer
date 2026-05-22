import AppKit
import QuartzCore

private final class RecordingOverlayView: NSView {
    var audioLevel: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }

    var animationPhase: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }

    var progressPercent: Int? {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let container = bounds.insetBy(dx: 1, dy: 1)
        let background = NSBezierPath(roundedRect: container, xRadius: 12, yRadius: 12)
        NSColor.black.withAlphaComponent(0.88).setFill()
        background.fill()

        drawCrescendo()
        drawBird(level: audioLevel)
        drawProgress()
    }

    private func drawCrescendo() {
        let level = max(0, min(1, audioLevel))
        let quietPulse = 0.08 + 0.05 * ((sin(animationPhase) + 1) / 2)
        let energy = max(level, quietPulse)

        let glow = NSBezierPath(ovalIn: NSRect(
            x: 32 - energy * 8,
            y: 20 - energy * 5,
            width: 78 + energy * 18,
            height: 44 + energy * 10
        ))
        NSColor(calibratedRed: 1.0, green: 0.73, blue: 0.20, alpha: 0.10 + energy * 0.18).setFill()
        glow.fill()

        for index in 0..<7 {
            let offset = CGFloat(index)
            let wave = (sin(animationPhase + offset * 0.72) + 1) / 2
            let height = 6 + energy * (9 + wave * 19)
            let x = 15 + offset * 7
            let y = bounds.maxY - 10 - height
            let bar = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 3.5, height: height), xRadius: 1.75, yRadius: 1.75)
            NSColor(calibratedRed: 0.18, green: 0.74, blue: 0.82, alpha: 0.22 + energy * 0.42).setFill()
            bar.fill()
        }

        for index in 0..<3 {
            let offset = CGFloat(index)
            let wave = (sin(animationPhase + offset * 0.9) + 1) / 2
            let spread = 8 + offset * 7 + energy * (3 + offset * 2) + wave * 2
            let x = 105 + offset * 8
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: 32 - spread))
            path.curve(
                to: NSPoint(x: x, y: 32 + spread),
                controlPoint1: NSPoint(x: x + 10 + energy * 9, y: 27 - spread * 0.35),
                controlPoint2: NSPoint(x: x + 10 + energy * 9, y: 37 + spread * 0.35)
            )
            path.lineWidth = 1.4 + energy * 2.4
            path.lineCapStyle = .round
            NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.22, alpha: 0.18 + energy * 0.48 - offset * 0.07).setStroke()
            path.stroke()
        }
    }

    private func drawBird(level: CGFloat) {
        let center = NSPoint(x: 68, y: 40)
        let scale = 1 + max(0, min(1, level)) * 0.075
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.scale(by: scale)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()

        let body = NSBezierPath(ovalIn: NSRect(x: 45, y: 29, width: 43, height: 27))
        NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
        body.fill()

        let head = NSBezierPath(ovalIn: NSRect(x: 76, y: 18, width: 24, height: 24))
        head.fill()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 47, y: 38))
        tail.line(to: NSPoint(x: 28, y: 27))
        tail.line(to: NSPoint(x: 36, y: 41))
        tail.line(to: NSPoint(x: 28, y: 53))
        tail.close()
        tail.fill()

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: 98, y: 27))
        beak.line(to: NSPoint(x: 111, y: 31))
        beak.line(to: NSPoint(x: 98, y: 36))
        beak.close()
        NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.22, alpha: 1).setFill()
        beak.fill()

        NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 88, y: 26, width: 4, height: 4)).fill()

        let wing = NSBezierPath()
        wing.move(to: NSPoint(x: 58, y: 41))
        wing.curve(
            to: NSPoint(x: 78, y: 39),
            controlPoint1: NSPoint(x: 62, y: 29),
            controlPoint2: NSPoint(x: 74, y: 30)
        )
        wing.curve(
            to: NSPoint(x: 58, y: 41),
            controlPoint1: NSPoint(x: 75, y: 50),
            controlPoint2: NSPoint(x: 64, y: 53)
        )
        NSColor(calibratedWhite: 0.78, alpha: 1).setFill()
        wing.fill()

        NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.22, alpha: 1).setStroke()
        let leftFoot = NSBezierPath()
        leftFoot.lineWidth = 2
        leftFoot.move(to: NSPoint(x: 61, y: 56))
        leftFoot.line(to: NSPoint(x: 57, y: 62))
        leftFoot.stroke()

        let rightFoot = NSBezierPath()
        rightFoot.lineWidth = 2
        rightFoot.move(to: NSPoint(x: 74, y: 56))
        rightFoot.line(to: NSPoint(x: 78, y: 62))
        rightFoot.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawProgress() {
        guard let progressPercent else {
            return
        }

        let text = "\(max(0, min(100, progressPercent)))%"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(
            x: bounds.maxX - size.width - 12,
            y: bounds.maxY - size.height - 8
        )
        text.draw(at: point, withAttributes: attributes)
    }
}
final class RecordingOverlayController {
    private let panel: NSPanel
    private let overlayView: RecordingOverlayView
    private var isVisible = false

    init() {
        let size = NSSize(width: 140, height: 76)
        overlayView = RecordingOverlayView(frame: NSRect(origin: .zero, size: size))
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = overlayView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    func show(progressPercent: Int? = nil) {
        overlayView.progressPercent = progressPercent
        guard !isVisible else {
            return
        }

        isVisible = true
        positionPanel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isVisible else {
            overlayView.progressPercent = nil
            overlayView.audioLevel = 0
            return
        }

        isVisible = false
        overlayView.progressPercent = nil
        overlayView.audioLevel = 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, !self.isVisible else {
                return
            }
            self.panel.orderOut(nil)
        }
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else {
            return
        }

        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height - 42
        )
        panel.setFrameOrigin(origin)
    }

    func setProgress(_ progressPercent: Int?) {
        overlayView.progressPercent = progressPercent
    }

    func setAudioLevel(_ level: Float) {
        let clampedLevel = max(0, min(1, CGFloat(level)))
        overlayView.audioLevel = overlayView.audioLevel + (clampedLevel - overlayView.audioLevel) * 0.35
        overlayView.animationPhase += 0.18 + clampedLevel * 0.22
    }
}
