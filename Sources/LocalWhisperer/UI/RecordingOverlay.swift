import AppKit
import QuartzCore

private final class RecordingOverlayView: NSView {
    private let baseDrawingSize = NSSize(width: 140, height: 76)

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

    var statusText = "Recording" {
        didSet { needsDisplay = true }
    }

    var contextText = "" {
        didSet { needsDisplay = true }
    }

    var previewText = "" {
        didSet { needsDisplay = true }
    }

    var hintText = "Esc cancels" {
        didSet { needsDisplay = true }
    }

    var presenterMode = false {
        didSet { needsDisplay = true }
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

        if presenterMode {
            drawPresenterMode()
            drawProgress()
            return
        }

        NSGraphicsContext.saveGraphicsState()
        let drawingTransform = NSAffineTransform()
        drawingTransform.translateX(by: 12, yBy: 30)
        drawingTransform.concat()
        drawCrescendo()
        drawBird(level: audioLevel)
        NSGraphicsContext.restoreGraphicsState()
        drawText()
        drawProgress()
    }

    private func drawPresenterMode() {
        NSGraphicsContext.saveGraphicsState()
        let drawingTransform = NSAffineTransform()
        drawingTransform.translateX(by: 20, yBy: 72)
        drawingTransform.scale(by: 1.55)
        drawingTransform.concat()
        drawCrescendo()
        drawBird(level: audioLevel)
        NSGraphicsContext.restoreGraphicsState()

        let textX: CGFloat = 225
        let maxWidth = bounds.width - textX - 24
        let isPasted = statusText.localizedCaseInsensitiveContains("pasted")

        if isPasted {
            let checkAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 44, weight: .bold),
                .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 1)
            ]
            "✓".draw(at: NSPoint(x: bounds.maxX - 70, y: 20), withAttributes: checkAttributes)
        }

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.96)
        ]
        statusText.draw(
            in: NSRect(x: textX, y: 30, width: isPasted ? maxWidth - 64 : maxWidth, height: 36),
            withAttributes: titleAttributes
        )

        let preview = previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Listening..."
            : previewText
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let previewAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.84),
            .paragraphStyle: paragraph
        ]
        preview.draw(
            in: NSRect(x: textX, y: 78, width: maxWidth, height: 84),
            withAttributes: previewAttributes
        )

        let hintAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 0.72)
        ]
        let hint = isPasted ? "Ready for the next one" : hintText
        hint.draw(
            in: NSRect(x: textX, y: bounds.maxY - 38, width: maxWidth - 48, height: 18),
            withAttributes: hintAttributes
        )
    }

    private func drawText() {
        let textX: CGFloat = 148
        let maxWidth = bounds.width - textX - 18

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.95)
        ]
        statusText.draw(
            in: NSRect(x: textX, y: 14, width: maxWidth, height: 20),
            withAttributes: titleAttributes
        )

        let contextAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 0.9)
        ]
        contextText.draw(
            in: NSRect(x: textX, y: 35, width: maxWidth, height: 16),
            withAttributes: contextAttributes
        )

        let preview = previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Listening..."
            : previewText
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let previewAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.white.withAlphaComponent(0.78),
            .paragraphStyle: paragraph
        ]
        preview.draw(
            in: NSRect(x: textX, y: 56, width: maxWidth, height: 42),
            withAttributes: previewAttributes
        )

        let hintAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.46)
        ]
        hintText.draw(
            in: NSRect(x: textX, y: bounds.maxY - 24, width: maxWidth - 42, height: 14),
            withAttributes: hintAttributes
        )
    }

    private func drawCrescendo() {
        let level = max(0, min(1, audioLevel))
        let quietPulse = 0.08 + 0.05 * ((sin(animationPhase) + 1) / 2)
        let energy = max(level, quietPulse)

        let glowRect = NSRect(
            x: 34 - energy * 7,
            y: 18 - energy * 5,
            width: 76 + energy * 16,
            height: 48 + energy * 11
        )
        let glow = NSBezierPath(roundedRect: glowRect, xRadius: 11, yRadius: 11)
        NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.16, alpha: 0.12 + energy * 0.26).setFill()
        glow.fill()

        let coreRect = NSRect(
            x: 39 - energy * 4,
            y: 23 - energy * 3,
            width: 66 + energy * 9,
            height: 38 + energy * 7
        )
        let core = NSBezierPath(roundedRect: coreRect, xRadius: 9, yRadius: 9)
        NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 0.08 + energy * 0.18).setFill()
        core.fill()

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

        for index in 0..<4 {
            let offset = CGFloat(index)
            let wave = (sin(animationPhase * 1.2 + offset * 1.1) + 1) / 2
            let size = 2.2 + energy * 2.1 + wave * 0.8
            let dotRect = NSRect(
                x: 113 + offset * 6 + energy * 4,
                y: 26 + ((offset.truncatingRemainder(dividingBy: 2) == 0) ? -1 : 13) + wave * 6,
                width: size,
                height: size
            )
            NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 0.22 + energy * 0.48).setFill()
            NSBezierPath(ovalIn: dotRect).fill()
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
    private static let standardSize = NSSize(width: 360, height: 142)
    private static let presenterSize = NSSize(width: 560, height: 220)

    private let panel: NSPanel
    private let overlayView: RecordingOverlayView
    private var isVisible = false
    private var presenterMode = false

    init() {
        let size = Self.standardSize
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

    func show(
        progressPercent: Int? = nil,
        statusText: String? = nil,
        contextText: String? = nil,
        previewText: String? = nil,
        hintText: String? = nil,
        presenterMode: Bool? = nil
    ) {
        if let presenterMode {
            setPresenterMode(presenterMode)
        }
        overlayView.progressPercent = progressPercent
        if let statusText {
            overlayView.statusText = statusText
        }
        if let contextText {
            overlayView.contextText = contextText
        }
        if let previewText {
            overlayView.previewText = previewText
        }
        if let hintText {
            overlayView.hintText = hintText
        }
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
            overlayView.previewText = ""
            return
        }

        isVisible = false
        overlayView.progressPercent = nil
        overlayView.audioLevel = 0
        overlayView.previewText = ""

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

    func setPresenterMode(_ enabled: Bool) {
        guard presenterMode != enabled || overlayView.presenterMode != enabled else {
            return
        }

        presenterMode = enabled
        overlayView.presenterMode = enabled
        let size = enabled ? Self.presenterSize : Self.standardSize
        overlayView.frame = NSRect(origin: .zero, size: size)

        var frame = panel.frame
        frame.size = size
        panel.setFrame(frame, display: true)
        positionPanel()
    }

    func setProgress(_ progressPercent: Int?) {
        overlayView.progressPercent = progressPercent
    }

    func setDetails(
        statusText: String,
        contextText: String,
        previewText: String,
        hintText: String = "Esc cancels",
        presenterMode: Bool? = nil
    ) {
        if let presenterMode {
            setPresenterMode(presenterMode)
        }
        overlayView.statusText = statusText
        overlayView.contextText = contextText
        overlayView.previewText = previewText
        overlayView.hintText = hintText
    }

    func setAudioLevel(_ level: Float) {
        let clampedLevel = max(0, min(1, CGFloat(level)))
        overlayView.audioLevel = overlayView.audioLevel + (clampedLevel - overlayView.audioLevel) * 0.35
        overlayView.animationPhase += 0.18 + clampedLevel * 0.22
    }
}
