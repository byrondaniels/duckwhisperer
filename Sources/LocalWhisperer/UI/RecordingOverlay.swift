import AppKit
import QuartzCore

private final class RecordingOverlayView: NSView {
    private let baseDrawingSize = NSSize(width: 140, height: 76)

    var audioLevel: CGFloat = 0
    var animationPhase: CGFloat = 0

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

    func setAnimationState(audioLevel: CGFloat, animationPhase: CGFloat) {
        self.audioLevel = audioLevel
        self.animationPhase = animationPhase
        needsDisplay = true
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
        drawPlumeMark(level: audioLevel)
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
        drawPlumeMark(level: audioLevel)
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

        let preview = previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let previewAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.84),
            .paragraphStyle: paragraph
        ]
        if !preview.isEmpty {
            preview.draw(
                in: NSRect(x: textX, y: previewY, width: maxWidth, height: previewHeight),
                withAttributes: previewAttributes
            )
        }

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

        let preview = previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let previewAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.white.withAlphaComponent(0.78),
            .paragraphStyle: paragraph
        ]
        let previewY: CGFloat = hasContext || commandText != nil ? 56 : 38
        let previewHeight: CGFloat = hasContext || commandText != nil ? 42 : 60
        if !preview.isEmpty {
            preview.draw(
                in: NSRect(x: textX, y: previewY, width: maxWidth, height: previewHeight),
                withAttributes: previewAttributes
            )
        }

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
        let quietPulse = 0.025 + 0.018 * ((sin(animationPhase) + 1) / 2)
        let energy = max(pow(level, 1.18), quietPulse)
        let lift = pow(energy, 0.78)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.12, alpha: 0.10 + lift * 0.36)
        shadow.shadowBlurRadius = 8 + lift * 28
        shadow.shadowOffset = NSSize(width: 0, height: 3 + lift * 5)
        shadow.set()

        let stageRect = NSRect(
            x: 16 - lift * 7,
            y: 12 - lift * 5,
            width: 116 + lift * 14,
            height: 64 + lift * 10
        )
        let stage = NSBezierPath(roundedRect: stageRect, xRadius: 18, yRadius: 18)
        NSGradient(
            colors: [
                NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.22, alpha: 0.10 + lift * 0.30),
                NSColor(calibratedRed: 0.95, green: 0.54, blue: 0.10, alpha: 0.07 + lift * 0.23)
            ]
        )?.draw(in: stage, angle: 270)
        NSGraphicsContext.restoreGraphicsState()

        NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.55, alpha: 0.10 + lift * 0.34).setStroke()
        stage.lineWidth = 1
        stage.stroke()

        let shine = NSBezierPath(roundedRect: NSRect(x: 28, y: 18, width: 78, height: 15), xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.045 + lift * 0.10).setFill()
        shine.fill()
    }

    private func drawPlumeMark(level: CGFloat) {
        let center = NSPoint(x: 72, y: 43)
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

        drawMascotWaves(energy: energy)
        drawMascotBody(energy: energy)
        drawMascotHead(energy: energy)

        let noShadow = NSShadow()
        noShadow.shadowBlurRadius = 0
        noShadow.shadowOffset = .zero
        noShadow.set()

        drawMascotFace(energy: energy)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawMascotWaves(energy: CGFloat) {
        let quiet = energy < 0.11
        let loudness = pow(max(0, min(1, energy)), 0.68)
        let waveAlpha = 0.20 + loudness * 0.74
        let strokeColor = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.18, alpha: waveAlpha)

        for side in [-1.0, 1.0] {
            let direction = CGFloat(side)
            for index in 0..<3 {
                let offset = CGFloat(index)
                let phase = (sin(animationPhase * 1.4 + offset * 0.86) + 1) / 2
                let quietScale: CGFloat = quiet ? 0.54 : 1
                let radius = (10 + offset * 7) * quietScale + loudness * (10 + offset * 5) + phase * (1.2 + loudness * 4.4)
                let center = NSPoint(x: 72 + direction * (18 + offset * 2 + loudness * 3), y: 41)
                let path = NSBezierPath()
                path.lineWidth = 2.1 + loudness * 1.6 - offset * 0.28
                path.lineCapStyle = .round
                path.move(to: NSPoint(x: center.x + direction * radius * 0.18, y: center.y - radius * 0.72))
                path.curve(
                    to: NSPoint(x: center.x + direction * radius * 0.18, y: center.y + radius * 0.72),
                    controlPoint1: NSPoint(x: center.x + direction * radius, y: center.y - radius * 0.45),
                    controlPoint2: NSPoint(x: center.x + direction * radius, y: center.y + radius * 0.45)
                )
                strokeColor.withAlphaComponent(waveAlpha - offset * 0.12).setStroke()
                path.stroke()
            }

            let dotSize = 3.2 + loudness * 3.6
            let dot = NSBezierPath(
                ovalIn: NSRect(
                    x: 72 + direction * (46 + loudness * 15) - dotSize / 2,
                    y: 41 - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
            )
            strokeColor.withAlphaComponent(0.32 + loudness * 0.56).setFill()
            dot.fill()
        }
    }

    private func drawMascotBody(energy: CGFloat) {
        let shadow = NSBezierPath(ovalIn: NSRect(x: 59, y: 72, width: 28, height: 6))
        NSColor.black.withAlphaComponent(0.22).setFill()
        shadow.fill()

        let stem = NSBezierPath()
        stem.lineWidth = 4
        stem.lineCapStyle = .round
        stem.move(to: NSPoint(x: 72, y: 61))
        stem.curve(
            to: NSPoint(x: 72, y: 74),
            controlPoint1: NSPoint(x: 69, y: 66),
            controlPoint2: NSPoint(x: 75, y: 69)
        )
        NSColor(calibratedWhite: 0.82, alpha: 0.96).setStroke()
        stem.stroke()

        let body = NSBezierPath()
        body.move(to: NSPoint(x: 55, y: 57))
        body.curve(
            to: NSPoint(x: 72, y: 70),
            controlPoint1: NSPoint(x: 55, y: 66),
            controlPoint2: NSPoint(x: 63, y: 70)
        )
        body.curve(
            to: NSPoint(x: 89, y: 57),
            controlPoint1: NSPoint(x: 81, y: 70),
            controlPoint2: NSPoint(x: 89, y: 66)
        )
        body.curve(
            to: NSPoint(x: 72, y: 47),
            controlPoint1: NSPoint(x: 88, y: 50),
            controlPoint2: NSPoint(x: 82, y: 47)
        )
        body.curve(
            to: NSPoint(x: 55, y: 57),
            controlPoint1: NSPoint(x: 62, y: 47),
            controlPoint2: NSPoint(x: 56, y: 50)
        )
        body.close()
        NSGradient(colors: [
            NSColor.white,
            NSColor(calibratedWhite: 0.82, alpha: 1)
        ])?.draw(in: body, angle: 90)
        NSColor.white.withAlphaComponent(0.52 + energy * 0.16).setStroke()
        body.lineWidth = 1
        body.stroke()

        let rightWing = NSBezierPath()
        rightWing.lineWidth = 4
        rightWing.lineCapStyle = .round
        rightWing.move(to: NSPoint(x: 84, y: 54))
        rightWing.curve(
            to: NSPoint(x: 101, y: 48),
            controlPoint1: NSPoint(x: 91, y: 55),
            controlPoint2: NSPoint(x: 96, y: 52)
        )
        NSColor.white.withAlphaComponent(0.92).setStroke()
        rightWing.stroke()
    }

    private func drawMascotHead(energy: CGFloat) {
        let backPlume = NSBezierPath()
        backPlume.move(to: NSPoint(x: 57, y: 49))
        backPlume.curve(
            to: NSPoint(x: 76, y: 12),
            controlPoint1: NSPoint(x: 55, y: 30),
            controlPoint2: NSPoint(x: 62, y: 17)
        )
        backPlume.curve(
            to: NSPoint(x: 76, y: 51),
            controlPoint1: NSPoint(x: 84, y: 24),
            controlPoint2: NSPoint(x: 86, y: 41)
        )
        backPlume.curve(
            to: NSPoint(x: 57, y: 49),
            controlPoint1: NSPoint(x: 71, y: 48),
            controlPoint2: NSPoint(x: 64, y: 48)
        )
        backPlume.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.56, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.64, blue: 0.06, alpha: 1)
        ])?.draw(in: backPlume, angle: 245)

        let frontPlume = NSBezierPath()
        frontPlume.move(to: NSPoint(x: 70, y: 51))
        frontPlume.curve(
            to: NSPoint(x: 100, y: 8),
            controlPoint1: NSPoint(x: 72, y: 26),
            controlPoint2: NSPoint(x: 86, y: 12)
        )
        frontPlume.curve(
            to: NSPoint(x: 88, y: 52),
            controlPoint1: NSPoint(x: 102, y: 27),
            controlPoint2: NSPoint(x: 100, y: 44)
        )
        frontPlume.curve(
            to: NSPoint(x: 70, y: 51),
            controlPoint1: NSPoint(x: 82, y: 50),
            controlPoint2: NSPoint(x: 76, y: 50)
        )
        frontPlume.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.70, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.71, blue: 0.10, alpha: 1)
        ])?.draw(in: frontPlume, angle: 235)

        let face = NSBezierPath(ovalIn: NSRect(x: 51, y: 38, width: 42, height: 28))
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.20, alpha: 1),
            NSColor(calibratedRed: 0.96, green: 0.57, blue: 0.06, alpha: 1)
        ])?.draw(in: face, angle: 270)
        NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.68, alpha: 0.38 + energy * 0.12).setStroke()
        face.lineWidth = 1
        face.stroke()

        let shine = NSBezierPath()
        shine.lineWidth = 1.1
        shine.lineCapStyle = .round
        shine.move(to: NSPoint(x: 76, y: 23))
        shine.curve(
            to: NSPoint(x: 90, y: 12),
            controlPoint1: NSPoint(x: 80, y: 18),
            controlPoint2: NSPoint(x: 85, y: 14)
        )
        NSColor.white.withAlphaComponent(0.34).setStroke()
        shine.stroke()
    }

    private func drawMascotFace(energy: CGFloat) {
        for eye in [
            NSRect(x: 62, y: 46, width: 7, height: 9),
            NSRect(x: 76, y: 46, width: 7, height: 9)
        ] {
            let eyePath = NSBezierPath(ovalIn: eye)
            NSColor(calibratedWhite: 0.055, alpha: 1).setFill()
            eyePath.fill()

            let glint = NSBezierPath(ovalIn: NSRect(x: eye.minX + 2.1, y: eye.minY + 1.6, width: 2, height: 2))
            NSColor.white.withAlphaComponent(0.92).setFill()
            glint.fill()
        }

        let smile = NSBezierPath()
        smile.lineWidth = 2
        smile.lineCapStyle = .round
        smile.move(to: NSPoint(x: 69, y: 57))
        smile.curve(
            to: NSPoint(x: 76, y: 57),
            controlPoint1: NSPoint(x: 70.5, y: 61 + energy * 0.8),
            controlPoint2: NSPoint(x: 74.5, y: 61 + energy * 0.8)
        )
        NSColor(calibratedWhite: 0.08, alpha: 0.9).setStroke()
        smile.stroke()

        for cheekX in [58.0, 84.0] {
            let path = NSBezierPath()
            path.appendOval(in: NSRect(x: CGFloat(cheekX), y: 55, width: 4, height: 2.5))
            NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.45, alpha: 0.34).setFill()
            path.fill()
        }
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
    private var animationTimer: Timer?
    private var targetAudioLevel: CGFloat = 0
    private var displayedAudioLevel: CGFloat = 0
    private var animationPhase: CGFloat = 0

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
        startAnimationTimer()
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
            targetAudioLevel = 0
            displayedAudioLevel = 0
            overlayView.setAnimationState(audioLevel: 0, animationPhase: animationPhase)
            overlayView.previewText = ""
            overlayView.commandText = nil
            stopAnimationTimer()
            return
        }

        isVisible = false
        overlayView.progressPercent = nil
        targetAudioLevel = 0
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
            self.displayedAudioLevel = 0
            self.overlayView.setAnimationState(audioLevel: 0, animationPhase: self.animationPhase)
            self.stopAnimationTimer()
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
        let gatedLevel = clampedLevel < 0.035 ? 0 : clampedLevel
        targetAudioLevel = pow(gatedLevel, 1.45)
    }

    private func startAnimationTimer() {
        guard animationTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.advanceAnimationFrame()
        }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func advanceAnimationFrame() {
        guard isVisible else {
            stopAnimationTimer()
            return
        }

        let smoothing: CGFloat = targetAudioLevel > displayedAudioLevel ? 0.34 : 0.12
        displayedAudioLevel += (targetAudioLevel - displayedAudioLevel) * smoothing
        if abs(displayedAudioLevel - targetAudioLevel) < 0.002 {
            displayedAudioLevel = targetAudioLevel
        }

        animationPhase += 0.055 + displayedAudioLevel * 0.42
        overlayView.setAnimationState(audioLevel: displayedAudioLevel, animationPhase: animationPhase)
    }
}
