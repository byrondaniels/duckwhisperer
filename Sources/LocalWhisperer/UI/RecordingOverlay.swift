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

    var commandText: String? {
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
        let background = NSBezierPath(roundedRect: container, xRadius: 15, yRadius: 15)
        NSGradient(
            colors: [
                NSColor(calibratedWhite: 0.045, alpha: 0.96),
                NSColor(calibratedWhite: 0.010, alpha: 0.92)
            ]
        )?.draw(in: background, angle: 270)
        NSColor.white.withAlphaComponent(0.10).setStroke()
        background.lineWidth = 1
        background.stroke()

        let highlight = NSBezierPath(roundedRect: container.insetBy(dx: 1.5, dy: 1.5), xRadius: 13, yRadius: 13)
        NSColor.white.withAlphaComponent(0.035).setStroke()
        highlight.lineWidth = 1
        highlight.stroke()

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

        let previewY: CGFloat
        let previewHeight: CGFloat
        if let commandText {
            drawCommandBadge(
                "Command: \(commandText)",
                x: textX,
                y: 70,
                maxWidth: maxWidth,
                fontSize: 15
            )
            previewY = 104
            previewHeight = 58
        } else {
            previewY = 78
            previewHeight = 84
        }

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
            in: NSRect(x: textX, y: previewY, width: maxWidth, height: previewHeight),
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

        let trimmedContext = contextText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContext = !trimmedContext.isEmpty

        if let commandText {
            drawCommandBadge(
                "Command: \(commandText)",
                x: textX,
                y: 32,
                maxWidth: maxWidth,
                fontSize: 11
            )
        } else if hasContext {
            let contextAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 0.9)
            ]
            trimmedContext.draw(
                in: NSRect(x: textX, y: 35, width: maxWidth, height: 16),
                withAttributes: contextAttributes
            )
        }

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
        let previewY: CGFloat = hasContext || commandText != nil ? 56 : 38
        let previewHeight: CGFloat = hasContext || commandText != nil ? 42 : 60
        preview.draw(
            in: NSRect(x: textX, y: previewY, width: maxWidth, height: previewHeight),
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

    private func drawCommandBadge(_ text: String, x: CGFloat, y: CGFloat, maxWidth: CGFloat, fontSize: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.52, green: 1.0, blue: 0.57, alpha: 0.96)
        ]
        let size = text.size(withAttributes: attributes)
        let width = min(maxWidth, size.width + 18)
        let rect = NSRect(x: x, y: y, width: width, height: fontSize + 10)
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        NSColor(calibratedRed: 0.04, green: 0.26, blue: 0.10, alpha: 0.92).setFill()
        path.fill()
        text.draw(
            in: NSRect(x: rect.minX + 9, y: rect.minY + 4, width: rect.width - 18, height: rect.height - 4),
            withAttributes: attributes
        )
    }

    private func drawCrescendo() {
        let level = max(0, min(1, audioLevel))
        let quietPulse = 0.08 + 0.05 * ((sin(animationPhase) + 1) / 2)
        let energy = max(level, quietPulse)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.12, alpha: 0.24 + energy * 0.18)
        shadow.shadowBlurRadius = 16 + energy * 12
        shadow.shadowOffset = NSSize(width: 0, height: 5)
        shadow.set()

        let stageRect = NSRect(
            x: 24 - energy * 3,
            y: 15 - energy * 2,
            width: 100 + energy * 6,
            height: 58 + energy * 4
        )
        let stage = NSBezierPath(roundedRect: stageRect, xRadius: 18, yRadius: 18)
        NSGradient(
            colors: [
                NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.30, alpha: 0.28 + energy * 0.20),
                NSColor(calibratedRed: 0.96, green: 0.54, blue: 0.12, alpha: 0.18 + energy * 0.16)
            ]
        )?.draw(in: stage, angle: 270)
        NSGraphicsContext.restoreGraphicsState()

        NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.55, alpha: 0.20 + energy * 0.20).setStroke()
        stage.lineWidth = 1
        stage.stroke()

        let shine = NSBezierPath(roundedRect: NSRect(x: 32, y: 21, width: 70, height: 16), xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.10 + energy * 0.05).setFill()
        shine.fill()

        for index in 0..<5 {
            let offset = CGFloat(index)
            let wave = (sin(animationPhase * 1.45 + offset * 0.78) + 1) / 2
            let height = 9 + wave * 12 + energy * (12 + offset * 1.4)
            let x = 105 + offset * 5.2
            let barRect = NSRect(x: x, y: 45 - height / 2, width: 3.2, height: height)
            let bar = NSBezierPath(roundedRect: barRect, xRadius: 1.6, yRadius: 1.6)
            NSColor(
                calibratedRed: 1.0,
                green: 0.78,
                blue: 0.24,
                alpha: 0.34 + energy * 0.38 - offset * 0.025
            ).setFill()
            bar.fill()
        }
    }

    private func drawBird(level: CGFloat) {
        let center = NSPoint(x: 68, y: 40)
        let energy = max(0, min(1, level))
        let scale = 1 + energy * 0.045
        let bob = sin(animationPhase * 1.15) * (0.6 + energy * 1.8)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.translateX(by: 0, yBy: bob)
        transform.scale(by: scale)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()

        let dropShadow = NSShadow()
        dropShadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
        dropShadow.shadowBlurRadius = 9
        dropShadow.shadowOffset = NSSize(width: 0, height: 4)
        dropShadow.set()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 47, y: 39))
        tail.line(to: NSPoint(x: 30, y: 29))
        tail.line(to: NSPoint(x: 36, y: 42))
        tail.line(to: NSPoint(x: 30, y: 53))
        tail.line(to: NSPoint(x: 49, y: 50))
        tail.close()
        NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
        tail.fill()

        let body = NSBezierPath(ovalIn: NSRect(x: 43, y: 31, width: 47, height: 28))
        NSGradient(
            colors: [
                NSColor(calibratedWhite: 1.0, alpha: 1),
                NSColor(calibratedWhite: 0.84, alpha: 1)
            ]
        )?.draw(in: body, angle: 265)
        NSColor(calibratedWhite: 1.0, alpha: 0.72).setStroke()
        body.lineWidth = 1
        body.stroke()

        let head = NSBezierPath(ovalIn: NSRect(x: 75, y: 18, width: 26, height: 26))
        NSGradient(
            colors: [
                NSColor(calibratedWhite: 1.0, alpha: 1),
                NSColor(calibratedWhite: 0.88, alpha: 1)
            ]
        )?.draw(in: head, angle: 250)
        NSColor(calibratedWhite: 1.0, alpha: 0.70).setStroke()
        head.lineWidth = 1
        head.stroke()

        let noShadow = NSShadow()
        noShadow.shadowBlurRadius = 0
        noShadow.shadowOffset = .zero
        noShadow.set()

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: 98, y: 27))
        beak.line(to: NSPoint(x: 114, y: 31.5))
        beak.line(to: NSPoint(x: 98, y: 36.5))
        beak.close()
        NSColor(calibratedRed: 1.0, green: 0.66, blue: 0.14, alpha: 1).setFill()
        beak.fill()
        NSColor(calibratedRed: 0.70, green: 0.36, blue: 0.05, alpha: 0.24).setStroke()
        beak.lineWidth = 0.8
        beak.stroke()

        NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 88.5, y: 26.2, width: 4.4, height: 4.4)).fill()
        NSColor.white.withAlphaComponent(0.8).setFill()
        NSBezierPath(ovalIn: NSRect(x: 90.2, y: 27.1, width: 1.2, height: 1.2)).fill()

        let wing = NSBezierPath()
        wing.move(to: NSPoint(x: 57, y: 43))
        wing.curve(
            to: NSPoint(x: 79, y: 40),
            controlPoint1: NSPoint(x: 62, y: 33),
            controlPoint2: NSPoint(x: 74, y: 32)
        )
        wing.curve(
            to: NSPoint(x: 57, y: 43),
            controlPoint1: NSPoint(x: 75, y: 51),
            controlPoint2: NSPoint(x: 64, y: 52)
        )
        NSGradient(
            colors: [
                NSColor(calibratedWhite: 0.78, alpha: 1),
                NSColor(calibratedWhite: 0.62, alpha: 1)
            ]
        )?.draw(in: wing, angle: 260)
        NSColor.white.withAlphaComponent(0.34).setStroke()
        wing.lineWidth = 0.8
        wing.stroke()

        NSColor(calibratedRed: 1.0, green: 0.69, blue: 0.18, alpha: 0.95).setStroke()
        let feet: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(62, 58, 57, 63), (75, 58, 80, 63)]
        for foot in feet {
            let path = NSBezierPath()
            path.lineWidth = 2.1
            path.lineCapStyle = .round
            path.move(to: NSPoint(x: foot.0, y: foot.1))
            path.line(to: NSPoint(x: foot.2, y: foot.3))
            path.stroke()
        }

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
        commandText: String? = nil,
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
        overlayView.commandText = commandText
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
            overlayView.commandText = nil
            return
        }

        isVisible = false
        overlayView.progressPercent = nil
        overlayView.audioLevel = 0
        overlayView.previewText = ""
        overlayView.commandText = nil

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
        commandText: String? = nil,
        presenterMode: Bool? = nil
    ) {
        if let presenterMode {
            setPresenterMode(presenterMode)
        }
        overlayView.statusText = statusText
        overlayView.contextText = contextText
        overlayView.previewText = previewText
        overlayView.hintText = hintText
        overlayView.commandText = commandText
    }

    func setAudioLevel(_ level: Float) {
        let clampedLevel = max(0, min(1, CGFloat(level)))
        overlayView.audioLevel = overlayView.audioLevel + (clampedLevel - overlayView.audioLevel) * 0.35
        overlayView.animationPhase += 0.18 + clampedLevel * 0.22
    }
}
