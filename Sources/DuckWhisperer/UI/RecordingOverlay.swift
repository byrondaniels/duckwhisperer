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
        drawDuckWhispererMark(level: audioLevel)
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
        drawDuckWhispererMark(level: audioLevel)
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
        let energy = max(pow(level, 1.28), quietPulse)
        let lift = pow(energy, 0.92)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.12, alpha: 0.09 + lift * 0.26)
        shadow.shadowBlurRadius = 8 + lift * 18
        shadow.shadowOffset = NSSize(width: 0, height: 3 + lift * 3)
        shadow.set()

        let stageRect = NSRect(
            x: 16 - lift * 4,
            y: 12 - lift * 3,
            width: 116 + lift * 8,
            height: 64 + lift * 6
        )
        let stage = NSBezierPath(roundedRect: stageRect, xRadius: 18, yRadius: 18)
        NSGradient(
            colors: [
                NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.22, alpha: 0.10 + lift * 0.22),
                NSColor(calibratedRed: 0.95, green: 0.54, blue: 0.10, alpha: 0.07 + lift * 0.17)
            ]
        )?.draw(in: stage, angle: 270)
        NSGraphicsContext.restoreGraphicsState()

        NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.55, alpha: 0.10 + lift * 0.24).setStroke()
        stage.lineWidth = 1
        stage.stroke()

        let shine = NSBezierPath(roundedRect: NSRect(x: 28, y: 18, width: 78, height: 15), xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.045 + lift * 0.07).setFill()
        shine.fill()
    }

    private func drawDuckWhispererMark(level: CGFloat) {
        let center = NSPoint(x: 72, y: 43)
        let energy = max(0, min(1, level))
        let scale = 1 + energy * 0.018
        let bob = sin(animationPhase * 0.92) * (0.25 + energy * 0.70)
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
        let loudness = pow(max(0, min(1, energy)), 0.82)
        let baseColor = NSColor(calibratedRed: 1.0, green: 0.77, blue: 0.15, alpha: 0.38 + loudness * 0.44)
        let groups: [CGFloat] = [38, 112]
        let baseHeights: [CGFloat] = [15, 25, 35, 25, 15]

        for groupX in groups {
            for (index, baseHeight) in baseHeights.enumerated() {
                let phase = (sin(animationPhase * 1.7 + CGFloat(index) * 0.7 + groupX * 0.03) + 1) / 2
                let barHeight = baseHeight + loudness * (8 + CGFloat(abs(index - 2)) * 2) + phase * (1.4 + loudness * 3.2)
                let barWidth: CGFloat = 4.5 + loudness * 1.1
                let barX = groupX + CGFloat(index - 2) * 8 - barWidth / 2
                let barRect = NSRect(x: barX, y: 43 - barHeight / 2, width: barWidth, height: barHeight)
                let bar = NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2)
                baseColor.withAlphaComponent(index == 2 ? 0.46 + loudness * 0.38 : 0.28 + loudness * 0.30).setFill()
                bar.fill()
            }
        }
    }

    private func drawMascotBody(energy: CGFloat) {
        let shadow = NSBezierPath(ovalIn: NSRect(x: 48, y: 70, width: 54, height: 8))
        NSColor.black.withAlphaComponent(0.22).setFill()
        shadow.fill()

        drawMascotFoot(origin: NSPoint(x: 54, y: 69), width: 18, height: 5)
        drawMascotFoot(origin: NSPoint(x: 70, y: 69), width: 20, height: 5)

        let raisedWing = NSBezierPath()
        raisedWing.move(to: NSPoint(x: 76, y: 52))
        raisedWing.curve(
            to: NSPoint(x: 116, y: 30),
            controlPoint1: NSPoint(x: 89, y: 42),
            controlPoint2: NSPoint(x: 105, y: 34)
        )
        raisedWing.curve(
            to: NSPoint(x: 100, y: 62),
            controlPoint1: NSPoint(x: 118, y: 43),
            controlPoint2: NSPoint(x: 112, y: 56)
        )
        raisedWing.curve(
            to: NSPoint(x: 76, y: 52),
            controlPoint1: NSPoint(x: 91, y: 65),
            controlPoint2: NSPoint(x: 82, y: 60)
        )
        raisedWing.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.78, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.14, alpha: 1)
        ])?.draw(in: raisedWing, angle: 90)

        for offset in [0, 1, 2] {
            let feather = NSBezierPath()
            feather.lineWidth = 1
            feather.lineCapStyle = .round
            let start = NSPoint(x: 88 + CGFloat(offset) * 6, y: 50 - CGFloat(offset) * 4)
            feather.move(to: start)
            feather.curve(
                to: NSPoint(x: start.x + 13, y: start.y - 11),
                controlPoint1: NSPoint(x: start.x + 4, y: start.y - 3),
                controlPoint2: NSPoint(x: start.x + 9, y: start.y - 8)
            )
            NSColor.white.withAlphaComponent(0.35).setStroke()
            feather.stroke()
        }

        let body = NSBezierPath()
        body.move(to: NSPoint(x: 47, y: 60))
        body.curve(
            to: NSPoint(x: 62, y: 35),
            controlPoint1: NSPoint(x: 39, y: 48),
            controlPoint2: NSPoint(x: 46, y: 34)
        )
        body.curve(
            to: NSPoint(x: 84, y: 54),
            controlPoint1: NSPoint(x: 79, y: 35),
            controlPoint2: NSPoint(x: 88, y: 44)
        )
        body.curve(
            to: NSPoint(x: 65, y: 70),
            controlPoint1: NSPoint(x: 85, y: 67),
            controlPoint2: NSPoint(x: 75, y: 72)
        )
        body.curve(
            to: NSPoint(x: 47, y: 60),
            controlPoint1: NSPoint(x: 55, y: 70),
            controlPoint2: NSPoint(x: 49, y: 66)
        )
        body.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.90, alpha: 1),
            NSColor(calibratedRed: 0.98, green: 0.84, blue: 0.48, alpha: 1)
        ])?.draw(in: body, angle: 90)
        NSColor.white.withAlphaComponent(0.52 + energy * 0.16).setStroke()
        body.lineWidth = 1
        body.stroke()

        let wing = NSBezierPath()
        wing.move(to: NSPoint(x: 54, y: 52))
        wing.curve(
            to: NSPoint(x: 74, y: 50),
            controlPoint1: NSPoint(x: 60, y: 60),
            controlPoint2: NSPoint(x: 70, y: 60)
        )
        wing.curve(
            to: NSPoint(x: 58, y: 63),
            controlPoint1: NSPoint(x: 72, y: 58),
            controlPoint2: NSPoint(x: 65, y: 64)
        )
        wing.curve(
            to: NSPoint(x: 54, y: 52),
            controlPoint1: NSPoint(x: 53, y: 62),
            controlPoint2: NSPoint(x: 51, y: 56)
        )
        wing.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.93, blue: 0.56, alpha: 0.96),
            NSColor(calibratedRed: 0.98, green: 0.66, blue: 0.10, alpha: 0.96)
        ])?.draw(in: wing, angle: 90)

        let neck = NSBezierPath()
        neck.move(to: NSPoint(x: 70, y: 47))
        neck.curve(
            to: NSPoint(x: 69, y: 25),
            controlPoint1: NSPoint(x: 69, y: 39),
            controlPoint2: NSPoint(x: 67, y: 30)
        )
        neck.curve(
            to: NSPoint(x: 84, y: 25),
            controlPoint1: NSPoint(x: 73, y: 21),
            controlPoint2: NSPoint(x: 80, y: 21)
        )
        neck.curve(
            to: NSPoint(x: 80, y: 49),
            controlPoint1: NSPoint(x: 86, y: 34),
            controlPoint2: NSPoint(x: 84, y: 43)
        )
        neck.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.91, alpha: 1),
            NSColor(calibratedRed: 0.99, green: 0.84, blue: 0.48, alpha: 1)
        ])?.draw(in: neck, angle: 90)

        drawMascotBowTie(center: NSPoint(x: 74, y: 49), scale: 7.5)
    }

    private func drawMascotHead(energy: CGFloat) {
        let head = NSBezierPath(ovalIn: NSRect(x: 68, y: 18, width: 31, height: 29))
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.90, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.45, alpha: 1)
        ])?.draw(in: head, angle: 270)
        NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.68, alpha: 0.38 + energy * 0.12).setStroke()
        head.lineWidth = 1
        head.stroke()

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: 96, y: 31))
        beak.curve(
            to: NSPoint(x: 120, y: 35),
            controlPoint1: NSPoint(x: 106, y: 27),
            controlPoint2: NSPoint(x: 116, y: 28)
        )
        beak.curve(
            to: NSPoint(x: 96, y: 40),
            controlPoint1: NSPoint(x: 116, y: 42),
            controlPoint2: NSPoint(x: 106, y: 44)
        )
        beak.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.08, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.40, blue: 0.03, alpha: 1)
        ])?.draw(in: beak, angle: 0)
    }

    private func drawMascotFace(energy: CGFloat) {
        let eye = NSBezierPath(ovalIn: NSRect(x: 79, y: 27, width: 6.2, height: 8.0))
        NSColor(calibratedWhite: 0.045, alpha: 1).setFill()
        eye.fill()

        let glint = NSBezierPath(ovalIn: NSRect(x: 81.0, y: 28.3, width: 1.7, height: 1.9))
        NSColor.white.withAlphaComponent(0.92).setFill()
        glint.fill()

        let smile = NSBezierPath()
        smile.lineWidth = 2
        smile.lineCapStyle = .round
        smile.move(to: NSPoint(x: 88, y: 38))
        smile.curve(
            to: NSPoint(x: 93, y: 38),
            controlPoint1: NSPoint(x: 89.0, y: 41 + energy * 0.5),
            controlPoint2: NSPoint(x: 92.0, y: 41 + energy * 0.5)
        )
        NSColor(calibratedWhite: 0.08, alpha: 0.9).setStroke()
        smile.stroke()

        let cheek = NSBezierPath(ovalIn: NSRect(x: 70, y: 39, width: 5, height: 3))
        NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.45, alpha: 0.34).setFill()
        cheek.fill()
    }

    private func drawMascotFoot(origin: NSPoint, width: CGFloat, height: CGFloat) {
        let foot = NSBezierPath()
        foot.move(to: origin)
        foot.curve(
            to: NSPoint(x: origin.x + width, y: origin.y),
            controlPoint1: NSPoint(x: origin.x + width * 0.32, y: origin.y - height),
            controlPoint2: NSPoint(x: origin.x + width * 0.74, y: origin.y - height * 0.8)
        )
        foot.curve(
            to: origin,
            controlPoint1: NSPoint(x: origin.x + width * 0.70, y: origin.y + height * 0.65),
            controlPoint2: NSPoint(x: origin.x + width * 0.22, y: origin.y + height * 0.50)
        )
        foot.close()
        NSColor(calibratedRed: 1.0, green: 0.58, blue: 0.05, alpha: 1).setFill()
        foot.fill()
    }

    private func drawMascotBowTie(center: NSPoint, scale: CGFloat) {
        let left = NSBezierPath()
        left.move(to: center)
        left.line(to: NSPoint(x: center.x - scale, y: center.y - scale * 0.45))
        left.line(to: NSPoint(x: center.x - scale, y: center.y + scale * 0.45))
        left.close()

        let right = NSBezierPath()
        right.move(to: center)
        right.line(to: NSPoint(x: center.x + scale, y: center.y - scale * 0.45))
        right.line(to: NSPoint(x: center.x + scale, y: center.y + scale * 0.45))
        right.close()

        NSColor(calibratedRed: 1.0, green: 0.63, blue: 0.08, alpha: 1).setFill()
        left.fill()
        right.fill()

        let knot = NSBezierPath(ovalIn: NSRect(x: center.x - scale * 0.23, y: center.y - scale * 0.21, width: scale * 0.46, height: scale * 0.42))
        NSColor(calibratedRed: 0.88, green: 0.39, blue: 0.02, alpha: 1).setFill()
        knot.fill()
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
        let noiseFloor: CGFloat = 0.015
        let gatedLevel = max(0, (clampedLevel - noiseFloor) / (1 - noiseFloor))
        targetAudioLevel = min(0.78, pow(gatedLevel, 1.12) * 0.88)
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

        let smoothing: CGFloat = targetAudioLevel > displayedAudioLevel ? 0.30 : 0.10
        displayedAudioLevel += (targetAudioLevel - displayedAudioLevel) * smoothing
        if abs(displayedAudioLevel - targetAudioLevel) < 0.002 {
            displayedAudioLevel = targetAudioLevel
        }

        animationPhase += 0.038 + displayedAudioLevel * 0.24
        overlayView.setAnimationState(audioLevel: displayedAudioLevel, animationPhase: animationPhase)
    }
}
