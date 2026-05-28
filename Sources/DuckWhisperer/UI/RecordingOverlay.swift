import AppKit
import QuartzCore

private final class RecordingOverlayView: NSView {
    private let baseDrawingSize = NSSize(width: 140, height: 76)
    private static let hudArtwork: NSImage? = {
        guard let url = Bundle.main.url(forResource: "DuckWhispererOption3Hud", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

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
        let idlePulse = 0.030 + 0.020 * ((sin(animationPhase * 0.85) + 1) / 2)
        let voiceEnergy = level > 0.018 ? max(pow(level, 0.54), 0.18) : 0
        let lift = max(voiceEnergy, idlePulse)
        let shimmer = (sin(animationPhase * 1.6) + 1) / 2

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.12, alpha: 0.12 + lift * 0.34)
        shadow.shadowBlurRadius = 10 + lift * 28
        shadow.shadowOffset = NSSize(width: 0, height: 3 + lift * 5)
        shadow.set()

        let stageRect = NSRect(
            x: 14 - lift * 10,
            y: 11 - lift * 6,
            width: 120 + lift * 20,
            height: 66 + lift * 12
        )
        let stage = NSBezierPath(roundedRect: stageRect, xRadius: 18, yRadius: 18)
        NSGradient(
            colors: [
                NSColor(calibratedRed: 1.0, green: 0.83, blue: 0.22, alpha: 0.13 + lift * 0.34),
                NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.10, alpha: 0.08 + lift * 0.24)
            ]
        )?.draw(in: stage, angle: 270)
        NSGraphicsContext.restoreGraphicsState()

        for index in 0..<3 {
            let offset = CGFloat(index)
            let ripple = (sin(animationPhase * 1.35 + offset * 0.9) + 1) / 2
            let inset = CGFloat(index) * -3.5 - lift * (2.5 + offset * 1.8) - ripple * lift * 2.6
            let ring = NSBezierPath(
                roundedRect: stageRect.insetBy(dx: inset, dy: inset * 0.55),
                xRadius: 19 + lift * 6,
                yRadius: 19 + lift * 6
            )
            NSColor(
                calibratedRed: 1.0,
                green: 0.78,
                blue: 0.16,
                alpha: (0.030 + lift * 0.080) / (offset + 1)
            ).setStroke()
            ring.lineWidth = 1.0 + lift * 1.2
            ring.stroke()
        }

        NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.55, alpha: 0.12 + lift * 0.40).setStroke()
        stage.lineWidth = 1
        stage.stroke()

        let shine = NSBezierPath(
            roundedRect: NSRect(
                x: 24 + shimmer * 8,
                y: 17,
                width: 72 + lift * 22,
                height: 14 + lift * 3
            ),
            xRadius: 8,
            yRadius: 8
        )
        NSColor.white.withAlphaComponent(0.050 + lift * 0.12).setFill()
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

        if let hudArtwork = Self.hudArtwork {
            drawHudArtwork(hudArtwork, energy: energy)
            drawMascotWaves(energy: energy)
            NSGraphicsContext.restoreGraphicsState()
            return
        }

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

    private func drawHudArtwork(_ image: NSImage, energy: CGFloat) {
        let artBounds = NSRect(x: 28, y: 0, width: 98, height: 76)
        let targetRect = aspectFitRect(for: image.size, in: artBounds)

        let glow = NSShadow()
        glow.shadowColor = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.16, alpha: 0.10 + energy * 0.18)
        glow.shadowBlurRadius = 8 + energy * 9
        glow.shadowOffset = .zero
        glow.set()

        image.draw(
            in: targetRect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func aspectFitRect(for imageSize: NSSize, in targetRect: NSRect) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return targetRect
        }
        let scale = min(targetRect.width / imageSize.width, targetRect.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return NSRect(
            x: targetRect.midX - width / 2,
            y: targetRect.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func drawMascotWaves(energy: CGFloat) {
        let raw = max(0, min(1, energy))
        let idle = 0.055 + 0.030 * ((sin(animationPhase * 1.2) + 1) / 2)
        let loudness = raw > 0.018 ? max(pow(raw, 0.56), 0.24) : idle
        let baseColor = NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.12, alpha: 0.24 + loudness * 0.58)
        let groups: [CGFloat] = [24, 128]
        let baseHeights: [CGFloat] = [14, 24, 34, 24, 14]

        for groupX in groups {
            for (index, baseHeight) in baseHeights.enumerated() {
                let phase = (sin(animationPhase * (1.35 + loudness * 1.5) + CGFloat(index) * 0.72 + groupX * 0.035) + 1) / 2
                let polarity = CGFloat(3 - abs(index - 2))
                let barHeight = baseHeight * (0.52 + loudness * 0.76)
                    + loudness * (8 + polarity * 6)
                    + phase * (2.0 + loudness * 10.0)
                let barWidth: CGFloat = 3.8 + loudness * 2.2
                let barX = groupX + CGFloat(index - 2) * 8 - barWidth / 2
                let barRect = NSRect(x: barX, y: 43 - barHeight / 2, width: barWidth, height: barHeight)
                let bar = NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2)
                baseColor.withAlphaComponent(index == 2 ? 0.50 + loudness * 0.40 : 0.30 + loudness * 0.36).setFill()
                bar.fill()
            }
        }
    }

    private func drawMascotBody(energy: CGFloat) {
        let badgeRect = NSRect(x: 43, y: 8, width: 66, height: 66)
        let badge = NSBezierPath(ovalIn: badgeRect)
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.12, alpha: 0.18 + energy * 0.18),
            NSColor(calibratedRed: 0.40, green: 0.27, blue: 0.06, alpha: 0.10 + energy * 0.10)
        ])?.draw(in: badge, angle: 270)
        NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.18, alpha: 0.55 + energy * 0.22).setStroke()
        badge.lineWidth = 2.2
        badge.stroke()

        let innerGlow = NSBezierPath(ovalIn: badgeRect.insetBy(dx: 8, dy: 7))
        NSColor.white.withAlphaComponent(0.05 + energy * 0.05).setFill()
        innerGlow.fill()

        let neck = NSBezierPath()
        neck.move(to: NSPoint(x: 61, y: 67))
        neck.curve(
            to: NSPoint(x: 67, y: 35),
            controlPoint1: NSPoint(x: 53, y: 55),
            controlPoint2: NSPoint(x: 55, y: 42)
        )
        neck.curve(
            to: NSPoint(x: 87, y: 38),
            controlPoint1: NSPoint(x: 74, y: 29),
            controlPoint2: NSPoint(x: 84, y: 31)
        )
        neck.curve(
            to: NSPoint(x: 83, y: 67),
            controlPoint1: NSPoint(x: 91, y: 50),
            controlPoint2: NSPoint(x: 92, y: 62)
        )
        neck.curve(
            to: NSPoint(x: 61, y: 67),
            controlPoint1: NSPoint(x: 77, y: 75),
            controlPoint2: NSPoint(x: 67, y: 75)
        )
        neck.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.91, alpha: 1),
            NSColor(calibratedRed: 0.99, green: 0.84, blue: 0.46, alpha: 1)
        ])?.draw(in: neck, angle: 90)
    }

    private func drawMascotHead(energy: CGFloat) {
        let head = NSBezierPath(ovalIn: NSRect(x: 64, y: 21, width: 38, height: 34))
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.90, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.45, alpha: 1)
        ])?.draw(in: head, angle: 270)
        NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.68, alpha: 0.38 + energy * 0.12).setStroke()
        head.lineWidth = 1
        head.stroke()

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: 98, y: 34))
        beak.curve(
            to: NSPoint(x: 130, y: 40),
            controlPoint1: NSPoint(x: 111, y: 27),
            controlPoint2: NSPoint(x: 124, y: 29)
        )
        beak.curve(
            to: NSPoint(x: 98, y: 47),
            controlPoint1: NSPoint(x: 123, y: 52),
            controlPoint2: NSPoint(x: 111, y: 53)
        )
        beak.close()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.08, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.40, blue: 0.03, alpha: 1)
        ])?.draw(in: beak, angle: 0)
    }

    private func drawMascotFace(energy: CGFloat) {
        let eye = NSBezierPath(ovalIn: NSRect(x: 78, y: 30, width: 7.0, height: 9.0))
        NSColor(calibratedWhite: 0.045, alpha: 1).setFill()
        eye.fill()

        let glint = NSBezierPath(ovalIn: NSRect(x: 80.2, y: 31.5, width: 1.9, height: 2.1))
        NSColor.white.withAlphaComponent(0.92).setFill()
        glint.fill()

        let smile = NSBezierPath()
        smile.lineWidth = 2
        smile.lineCapStyle = .round
        smile.move(to: NSPoint(x: 91, y: 45))
        smile.curve(
            to: NSPoint(x: 98, y: 45),
            controlPoint1: NSPoint(x: 92.5, y: 49 + energy * 0.5),
            controlPoint2: NSPoint(x: 96.5, y: 49 + energy * 0.5)
        )
        NSColor(calibratedWhite: 0.08, alpha: 0.9).setStroke()
        smile.stroke()

        let cheek = NSBezierPath(ovalIn: NSRect(x: 69, y: 44, width: 5, height: 3))
        NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.45, alpha: 0.34).setFill()
        cheek.fill()
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
    private static let overlayCollectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .transient,
        .ignoresCycle
    ]

    private let panel: NSPanel
    private let overlayView: RecordingOverlayView
    private var isVisible = false
    private var presenterMode = false
    private var animationTimer: Timer?
    private var activeSpaceObserver: NSObjectProtocol?
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
        panel.collectionBehavior = Self.overlayCollectionBehavior

        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleActiveSpaceDidChange()
        }
    }

    deinit {
        if let activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceObserver)
        }
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
        if isVisible {
            revealOnActiveSpace()
            return
        }

        isVisible = true
        revealOnActiveSpace()
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
        guard let screen = activeScreen() else {
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

    private func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func revealOnActiveSpace() {
        panel.collectionBehavior = Self.overlayCollectionBehavior
        positionPanel()
        panel.orderFrontRegardless()
    }

    private func handleActiveSpaceDidChange() {
        guard isVisible else {
            return
        }

        revealOnActiveSpace()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self, self.isVisible else {
                return
            }
            self.revealOnActiveSpace()
        }
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
        let noiseFloor: CGFloat = 0.004
        let gatedLevel = max(0, (clampedLevel - noiseFloor) / (1 - noiseFloor))
        guard gatedLevel > 0 else {
            targetAudioLevel = 0
            return
        }

        let shapedLevel = pow(gatedLevel, 0.58) * 1.28
        targetAudioLevel = min(0.98, max(0.16, shapedLevel))
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
