import AppKit
import QuartzCore

private final class RecordingOverlayView: NSView {
    private static let hudArtwork: NSImage? = {
        guard let url = Bundle.main.url(forResource: "DuckWhispererOption3Hud", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    var audioLevel: CGFloat = 0
    var audioAccent: CGFloat = 0
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

    func setAnimationState(audioLevel: CGFloat, audioAccent: CGFloat, animationPhase: CGFloat) {
        self.audioLevel = audioLevel
        self.audioAccent = audioAccent
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

        drawCenteredMode()
        drawProgress()
    }

    private func drawCenteredMode() {
        drawCenteredTitle()
        drawCenteredContext()

        NSGraphicsContext.saveGraphicsState()
        let drawingTransform = NSAffineTransform()
        let mascotScale: CGFloat = 1.48
        drawingTransform.translateX(by: bounds.midX - 72 * mascotScale, yBy: 68)
        drawingTransform.scale(by: mascotScale)
        drawingTransform.concat()
        drawCrescendo()
        drawDuckWhispererMark(level: audioLevel, accent: audioAccent)
        NSGraphicsContext.restoreGraphicsState()

        drawCenteredPreview()
        drawCenteredHint()
    }

    private func drawPresenterMode() {
        NSGraphicsContext.saveGraphicsState()
        let drawingTransform = NSAffineTransform()
        drawingTransform.translateX(by: 20, yBy: 72)
        drawingTransform.scale(by: 1.55)
        drawingTransform.concat()
        drawCrescendo()
        drawDuckWhispererMark(level: audioLevel, accent: audioAccent)
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

    private func drawCenteredTitle() {
        let isPasted = statusText.localizedCaseInsensitiveContains("pasted")
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.96)
        ]
        let titleRect = NSRect(x: 24, y: 16, width: bounds.width - 48, height: 28)
        drawCentered(statusText, in: titleRect, attributes: titleAttributes)

        if isPasted {
            let checkAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 0.95)
            ]
            "✓".draw(
                at: NSPoint(x: titleRect.maxX - 18, y: titleRect.minY + 1),
                withAttributes: checkAttributes
            )
        }
    }

    private func drawCenteredContext() {
        if let commandText {
            drawCenteredBadge("Command: \(commandText)", y: 47, maxWidth: bounds.width - 52)
            return
        }

        let trimmedContext = contextText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContext.isEmpty else {
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.32, alpha: 0.94)
        ]
        let size = trimmedContext.size(withAttributes: attributes)
        let width = min(bounds.width - 70, size.width + 20)
        let rect = NSRect(x: bounds.midX - width / 2, y: 48, width: width, height: 22)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.05, alpha: 0.66).setFill()
        path.fill()
        NSColor(calibratedRed: 1.0, green: 0.77, blue: 0.20, alpha: 0.16).setStroke()
        path.lineWidth = 1
        path.stroke()
        drawCentered(trimmedContext, in: rect.insetBy(dx: 10, dy: 3), attributes: attributes)
    }

    private func drawCenteredPreview() {
        let preview = previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback: String
        if statusText.localizedCaseInsensitiveContains("recording") {
            fallback = "Speak naturally"
        } else if statusText.localizedCaseInsensitiveContains("transcribing") {
            fallback = "Finalizing local transcript..."
        } else {
            fallback = ""
        }

        let text = preview.isEmpty ? fallback : preview
        guard !text.isEmpty else {
            return
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(preview.isEmpty ? 0.58 : 0.84),
            .paragraphStyle: paragraph
        ]
        let rect = NSRect(x: 32, y: 196, width: bounds.width - 64, height: 42)
        text.draw(in: rect, withAttributes: attributes)
    }

    private func drawCenteredHint() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.46)
        ]
        drawCentered(
            hintText,
            in: NSRect(x: 28, y: bounds.maxY - 27, width: bounds.width - 56, height: 15),
            attributes: attributes
        )
    }

    private func drawCentered(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        let mutableAttributes = NSMutableDictionary(dictionary: attributes)
        let paragraph = (attributes[.paragraphStyle] as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraph.alignment = .center
        mutableAttributes[NSAttributedString.Key.paragraphStyle] = paragraph
        text.draw(in: rect, withAttributes: mutableAttributes as? [NSAttributedString.Key: Any])
    }

    private func drawCenteredBadge(_ text: String, y: CGFloat, maxWidth: CGFloat) {
        let fontSize: CGFloat = 12
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.52, green: 1.0, blue: 0.57, alpha: 0.96)
        ]
        let size = text.size(withAttributes: attributes)
        let width = min(maxWidth, size.width + 20)
        let rect = NSRect(x: bounds.midX - width / 2, y: y, width: width, height: fontSize + 11)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor(calibratedRed: 0.04, green: 0.26, blue: 0.10, alpha: 0.92).setFill()
        path.fill()
        drawCentered(text, in: rect.insetBy(dx: 10, dy: 4), attributes: attributes)
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
        let accent = max(0, min(1, audioAccent))
        let idlePulse = 0.018 + 0.010 * ((sin(animationPhase * 0.85) + 1) / 2)
        let voiceEnergy = level > 0.018 ? max(pow(level, 0.54), 0.18) : 0
        let lift = min(1, max(voiceEnergy, idlePulse) + accent * 0.16)
        let shimmer = (sin(animationPhase * 1.6) + 1) / 2

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.12, alpha: 0.12 + lift * 0.34)
        shadow.shadowBlurRadius = 10 + lift * 10
        shadow.shadowOffset = NSSize(width: 0, height: 3 + lift * 2)
        shadow.set()

        let stageRect = NSRect(
            x: 14 - lift * 3,
            y: 11 - lift * 2,
            width: 120 + lift * 6,
            height: 66 + lift * 4
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
            let inset = CGFloat(index) * -3.5 - lift * (1.0 + offset * 0.6) - ripple * lift * 0.8
            let ring = NSBezierPath(
                roundedRect: stageRect.insetBy(dx: inset, dy: inset * 0.55),
                xRadius: 19 + lift * 2,
                yRadius: 19 + lift * 2
            )
            NSColor(
                calibratedRed: 1.0,
                green: 0.78,
                blue: 0.16,
                alpha: (0.030 + lift * 0.080) / (offset + 1)
            ).setStroke()
            ring.lineWidth = 1.0 + lift * 0.5
            ring.stroke()
        }

        NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.55, alpha: 0.12 + lift * 0.40).setStroke()
        stage.lineWidth = 1
        stage.stroke()

        let shine = NSBezierPath(
            roundedRect: NSRect(
                x: 24 + shimmer * 3,
                y: 17,
                width: 72 + lift * 8,
                height: 14 + lift * 1
            ),
            xRadius: 8,
            yRadius: 8
        )
        NSColor.white.withAlphaComponent(0.050 + lift * 0.12).setFill()
        shine.fill()
    }

    private func drawDuckWhispererMark(level: CGFloat, accent: CGFloat) {
        let center = NSPoint(x: 72, y: 43)
        let energy = max(0, min(1, level))
        let vocalAccent = max(0, min(1, accent))
        let isSpeaking = energy > 0.020
        let scale = 1 + energy * 0.005 + vocalAccent * 0.004
        let bob = isSpeaking ? sin(animationPhase * 0.62) * energy * 0.12 - vocalAccent * 0.18 : 0
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.translateX(by: 0, yBy: bob)
        transform.scale(by: scale)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()

        drawFlappingWings(energy: energy, accent: vocalAccent)

        if let hudArtwork = Self.hudArtwork {
            let dropShadow = NSShadow()
            dropShadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
            dropShadow.shadowBlurRadius = 9
            dropShadow.shadowOffset = NSSize(width: 0, height: 4)
            dropShadow.set()
            drawHudArtwork(hudArtwork, energy: energy)
            NSGraphicsContext.restoreGraphicsState()
            return
        }

        let dropShadow = NSShadow()
        dropShadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
        dropShadow.shadowBlurRadius = 9
        dropShadow.shadowOffset = NSSize(width: 0, height: 4)
        dropShadow.set()
        drawMascotBody(energy: energy)
        drawMascotHead(energy: energy)

        let noShadow = NSShadow()
        noShadow.shadowBlurRadius = 0
        noShadow.shadowOffset = .zero
        noShadow.set()

        drawMascotFace(energy: energy)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawFlappingWings(energy: CGFloat, accent: CGFloat) {
        let raw = max(0, min(1, energy))
        let vocalAccent = max(0, min(1, accent))
        let isSpeaking = raw > 0.030
        let loudness = isSpeaking ? max(pow(raw, 0.52), 0.24) : 0
        let responsiveLoudness = min(1, loudness + vocalAccent * 0.22)
        let wavePhase = animationPhase * (0.68 + responsiveLoudness * 0.76 + vocalAccent * 0.28)
        let waveAmplitude = isSpeaking ? min(1, smoothstep(loudness) * 0.78 + vocalAccent * 0.46) : 0

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 1.0, green: 0.58, blue: 0.10, alpha: 0.10 + responsiveLoudness * 0.16 + vocalAccent * 0.08)
        shadow.shadowBlurRadius = 8 + responsiveLoudness * 10 + vocalAccent * 5
        shadow.shadowOffset = NSSize(width: 0, height: 2)
        shadow.set()

        drawWing(
            side: -1,
            pivot: NSPoint(x: 64, y: 48),
            loudness: responsiveLoudness,
            wavePhase: wavePhase,
            waveAmplitude: waveAmplitude,
            vocalAccent: vocalAccent
        )
        drawWing(
            side: 1,
            pivot: NSPoint(x: 88, y: 48),
            loudness: responsiveLoudness,
            wavePhase: wavePhase,
            waveAmplitude: waveAmplitude,
            vocalAccent: vocalAccent
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawWing(
        side: CGFloat,
        pivot: NSPoint,
        loudness: CGFloat,
        wavePhase: CGFloat,
        waveAmplitude: CGFloat,
        vocalAccent: CGFloat
    ) {
        let offsets: [CGFloat] = [-1.90, -1.48, -1.08, -0.70, -0.33, 0.05, 0.42, 0.78, 1.12, 1.44, 1.74]
        let featherSpan = CGFloat(max(offsets.count - 1, 1))
        let baseLift: CGFloat = -11 - loudness * 5.2 - vocalAccent * 2.4
        let open = 0.78 + loudness * 0.13 + vocalAccent * 0.055

        drawWingMembrane(
            side: side,
            pivot: pivot,
            loudness: loudness,
            vocalAccent: vocalAccent,
            open: open,
            baseLift: baseLift,
            wavePhase: wavePhase,
            waveAmplitude: waveAmplitude
        )

        for (index, offset) in offsets.enumerated() {
            let rank = CGFloat(index)
            let progress = rank / featherSpan
            let featherPriority = CGFloat(offsets.count - index)

            let rootWave = waveAmplitude * sin(wavePhase + 0.16 - progress * 0.28) * (0.35 + loudness * 0.80 + vocalAccent * 0.70)
            let midWave = waveAmplitude * sin(wavePhase - 0.52 - progress * 0.88) * (1.55 + loudness * 3.35 + vocalAccent * 2.70)
            let tipWave = waveAmplitude * sin(wavePhase - 1.12 - progress * 1.50) * (2.90 + loudness * 5.25 + vocalAccent * 4.40)
            let sweepWave = waveAmplitude * cos(wavePhase - 0.88 - progress * 1.05) * (1.35 + loudness * 3.00 + vocalAccent * 2.10)
            let trailingDrop = 0.6 + pow(progress, 1.7) * (8.0 + loudness * 1.2)

            let extensionLength = 62 + loudness * 10 + vocalAccent * 8 + featherPriority * 4.4
            let tipX = pivot.x + side * (extensionLength + abs(offset) * 2.6 + sweepWave)
            let tipY = pivot.y + offset * 7.4 * open + baseLift + trailingDrop + tipWave + rank * 0.30
            let shoulderX = pivot.x + side * (extensionLength * 0.42 + loudness * 6)
            let shoulderY = pivot.y + offset * 4.8 * open + baseLift * 0.54 + trailingDrop * 0.36 + midWave + rank * 0.18
            let lowerShoulderY = shoulderY + 4.8 + progress * 2.8 + midWave * 0.14
            let rootTop = NSPoint(
                x: pivot.x + side * (2 + rank * 0.30),
                y: pivot.y - 4.2 + rank * 0.24 + rootWave
            )
            let rootBottom = NSPoint(
                x: pivot.x + side * (4 + rank * 0.32),
                y: pivot.y + 6.0 + rank * 0.30 + rootWave * 0.45
            )

            let path = NSBezierPath()
            path.move(to: rootTop)
            path.curve(
                to: NSPoint(x: shoulderX, y: shoulderY),
                controlPoint1: NSPoint(
                    x: pivot.x + side * (16 + loudness * 5),
                    y: rootTop.y + offset * 0.8 - loudness * 0.8 + midWave * 0.20
                ),
                controlPoint2: NSPoint(
                    x: shoulderX - side * (17 + loudness * 5),
                    y: shoulderY - 4.5 - loudness * 0.9
                )
            )
            path.curve(
                to: NSPoint(x: tipX, y: tipY),
                controlPoint1: NSPoint(
                    x: shoulderX + side * (29 + loudness * 7),
                    y: shoulderY + midWave * 0.16
                ),
                controlPoint2: NSPoint(
                    x: tipX - side * (35 + loudness * 8),
                    y: tipY - 4.5 - loudness * 1.3 + tipWave * 0.10
                )
            )
            path.curve(
                to: NSPoint(x: shoulderX, y: lowerShoulderY),
                controlPoint1: NSPoint(
                    x: tipX - side * (14 + loudness * 6),
                    y: tipY + 4.4 + progress * 1.4 + tipWave * 0.07
                ),
                controlPoint2: NSPoint(
                    x: shoulderX + side * (17 + loudness * 6),
                    y: lowerShoulderY + 3.2 + midWave * 0.18
                )
            )
            path.curve(
                to: rootBottom,
                controlPoint1: NSPoint(
                    x: shoulderX - side * (18 + loudness * 6),
                    y: lowerShoulderY + 2.8 + midWave * 0.10
                ),
                controlPoint2: NSPoint(
                    x: pivot.x + side * (24 + loudness * 7),
                    y: rootBottom.y + offset * 0.5 - rootWave * 0.30
                )
            )
            path.close()

            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            NSGradient(colors: [
                NSColor(calibratedRed: 1.0, green: 0.88, blue: 0.38, alpha: 0.80 + loudness * 0.14),
                NSColor(calibratedRed: 1.0, green: 0.60, blue: 0.10, alpha: 0.52 + loudness * 0.18)
            ])?.draw(in: path.bounds, angle: side < 0 ? 180 : 0)
            NSGraphicsContext.restoreGraphicsState()

            NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.18, alpha: 0.24 + loudness * 0.24).setStroke()
            path.lineWidth = 0.9
            path.stroke()

            let vein = NSBezierPath()
            vein.lineCapStyle = .round
            vein.lineWidth = 0.7
            vein.move(to: NSPoint(x: pivot.x + side * (12 + rank), y: pivot.y + rank * 0.7))
            vein.curve(
                to: NSPoint(x: shoulderX, y: shoulderY + 2.2),
                controlPoint1: NSPoint(x: pivot.x + side * 26, y: pivot.y + offset * 1.4 - loudness * 1.2 + midWave * 0.12),
                controlPoint2: NSPoint(x: shoulderX - side * 18, y: shoulderY + midWave * 0.16)
            )
            vein.curve(
                to: NSPoint(x: tipX - side * 8, y: tipY + 2),
                controlPoint1: NSPoint(x: shoulderX + side * 22, y: shoulderY + 3.2 + midWave * 0.14),
                controlPoint2: NSPoint(x: tipX - side * 28, y: tipY + 2 + tipWave * 0.08)
            )
            NSColor.white.withAlphaComponent(0.12 + loudness * 0.10).setStroke()
            vein.stroke()
        }
    }

    private func drawWingMembrane(
        side: CGFloat,
        pivot: NSPoint,
        loudness: CGFloat,
        vocalAccent: CGFloat,
        open: CGFloat,
        baseLift: CGFloat,
        wavePhase: CGFloat,
        waveAmplitude: CGFloat
    ) {
        let rootWave = waveAmplitude * sin(wavePhase + 0.10) * (0.35 + loudness * 0.75 + vocalAccent * 0.55)
        let midWave = waveAmplitude * sin(wavePhase - 0.56) * (1.35 + loudness * 2.90 + vocalAccent * 2.25)
        let tipWave = waveAmplitude * sin(wavePhase - 1.18) * (2.65 + loudness * 4.70 + vocalAccent * 3.65)
        let sweepWave = waveAmplitude * cos(wavePhase - 0.92) * (1.1 + loudness * 2.70 + vocalAccent * 1.75)
        let extensionLength = 112 + loudness * 7 + vocalAccent * 6 + sweepWave

        let rootTop = NSPoint(x: pivot.x + side * 3, y: pivot.y - 10.5 * open + rootWave)
        let rootBottom = NSPoint(x: pivot.x + side * 5, y: pivot.y + 12.5 * open + rootWave * 0.4)
        let shoulder = NSPoint(
            x: pivot.x + side * (extensionLength * 0.54),
            y: pivot.y - 9.5 * open + baseLift * 0.60 + midWave
        )
        let lowerShoulder = NSPoint(
            x: pivot.x + side * (extensionLength * 0.48),
            y: pivot.y + 7.5 * open + baseLift * 0.18 + midWave * 0.50
        )
        let tip = NSPoint(
            x: pivot.x + side * extensionLength,
            y: pivot.y - 6.5 * open + baseLift + tipWave
        )

        let membrane = NSBezierPath()
        membrane.move(to: rootTop)
        membrane.curve(
            to: shoulder,
            controlPoint1: NSPoint(x: pivot.x + side * (34 + loudness * 7), y: rootTop.y - 4.8 + midWave * 0.14),
            controlPoint2: NSPoint(x: shoulder.x - side * (28 + loudness * 7), y: shoulder.y - 7.5)
        )
        membrane.curve(
            to: tip,
            controlPoint1: NSPoint(x: shoulder.x + side * (32 + loudness * 7), y: shoulder.y + midWave * 0.08),
            controlPoint2: NSPoint(x: tip.x - side * (36 + loudness * 9), y: tip.y - 8.5 + tipWave * 0.10)
        )
        membrane.curve(
            to: lowerShoulder,
            controlPoint1: NSPoint(x: tip.x - side * (30 + loudness * 8), y: tip.y + 8.5 + tipWave * 0.10),
            controlPoint2: NSPoint(x: lowerShoulder.x + side * (26 + loudness * 7), y: lowerShoulder.y + 5.8)
        )
        membrane.curve(
            to: rootBottom,
            controlPoint1: NSPoint(x: lowerShoulder.x - side * (28 + loudness * 6), y: lowerShoulder.y + 4.2),
            controlPoint2: NSPoint(x: pivot.x + side * (34 + loudness * 7), y: rootBottom.y + 4.8)
        )
        membrane.close()

        NSGraphicsContext.saveGraphicsState()
        membrane.addClip()
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.22, alpha: 0.10 + loudness * 0.06 + vocalAccent * 0.035),
            NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.08, alpha: 0.035 + loudness * 0.045 + vocalAccent * 0.030)
        ])?.draw(in: membrane.bounds, angle: side < 0 ? 180 : 0)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func smoothstep(_ value: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, value))
        return clamped * clamped * (3 - 2 * clamped)
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
    private static let standardSize = NSSize(width: 440, height: 278)
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
    private var targetAudioAccent: CGFloat = 0
    private var displayedAudioAccent: CGFloat = 0
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
        if !isVisible {
            targetAudioLevel = 0
            displayedAudioLevel = 0
            targetAudioAccent = 0
            displayedAudioAccent = 0
            animationPhase = 0
            overlayView.setAnimationState(audioLevel: 0, audioAccent: 0, animationPhase: 0)
        }
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
            targetAudioAccent = 0
            displayedAudioAccent = 0
            overlayView.setAnimationState(audioLevel: 0, audioAccent: 0, animationPhase: animationPhase)
            overlayView.previewText = ""
            overlayView.commandText = nil
            stopAnimationTimer()
            return
        }

        isVisible = false
        overlayView.progressPercent = nil
        targetAudioLevel = 0
        targetAudioAccent = 0
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
            self.displayedAudioAccent = 0
            self.overlayView.setAnimationState(audioLevel: 0, audioAccent: 0, animationPhase: self.animationPhase)
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
        let noiseFloor: CGFloat = 0.010
        guard clampedLevel > noiseFloor else {
            targetAudioLevel = 0
            targetAudioAccent = 0
            return
        }
        let gatedLevel = max(0, (clampedLevel - noiseFloor) / (1 - noiseFloor))
        let shapedLevel = min(0.98, pow(gatedLevel, 0.58) * 1.10)
        let nextLevel = min(0.98, max(0.08, shapedLevel))
        let levelRise = max(0, nextLevel - targetAudioLevel)
        let displayRise = max(0, nextLevel - displayedAudioLevel)
        targetAudioLevel = nextLevel
        targetAudioAccent = min(1, max(targetAudioAccent * 0.55, levelRise * 4.6 + displayRise * 0.85))
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

        let smoothing: CGFloat = targetAudioLevel > displayedAudioLevel ? 0.23 : 0.10
        displayedAudioLevel += (targetAudioLevel - displayedAudioLevel) * smoothing
        if abs(displayedAudioLevel - targetAudioLevel) < 0.004 {
            displayedAudioLevel = targetAudioLevel
        }

        let accentSmoothing: CGFloat = targetAudioAccent > displayedAudioAccent ? 0.54 : 0.18
        displayedAudioAccent += (targetAudioAccent - displayedAudioAccent) * accentSmoothing
        targetAudioAccent *= 0.80
        if targetAudioLevel <= 0.020 {
            targetAudioAccent = 0
        }
        if displayedAudioLevel <= 0.018 && targetAudioAccent <= 0.020 {
            displayedAudioAccent = 0
        }
        if displayedAudioAccent < 0.006 {
            displayedAudioAccent = 0
        }

        if displayedAudioLevel > 0.020 {
            animationPhase += 0.012 + displayedAudioLevel * 0.038 + displayedAudioAccent * 0.034
        }
        overlayView.setAnimationState(
            audioLevel: displayedAudioLevel,
            audioAccent: displayedAudioAccent,
            animationPhase: animationPhase
        )
    }
}
