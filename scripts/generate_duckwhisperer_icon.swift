import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift generate_duckwhisperer_icon.swift /path/to/DuckWhisperer.icns\n", stderr)
    exit(EXIT_FAILURE)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let iconsetURL = outputURL.deletingPathExtension().appendingPathExtension("iconset")

try? fileManager.removeItem(at: iconsetURL)
try? fileManager.removeItem(at: outputURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let specs: [(points: Int, scale: Int, filename: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png")
]

var icnsChunks: [(type: String, data: Data)] = []
var addedChunkTypes = Set<String>()

for spec in specs {
    let pixels = spec.points * spec.scale
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    drawDuckWhispererIcon(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    image.unlockFocus()

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        fputs("Could not render \(spec.filename)\n", stderr)
        exit(EXIT_FAILURE)
    }

    try pngData.write(to: iconsetURL.appendingPathComponent(spec.filename))

    if let chunkType = icnsChunkType(forPixelSize: pixels),
       !addedChunkTypes.contains(chunkType) {
        addedChunkTypes.insert(chunkType)
        icnsChunks.append((type: chunkType, data: pngData))
    }
}

try writeICNS(chunks: icnsChunks, to: outputURL)

try? fileManager.removeItem(at: iconsetURL)

private func icnsChunkType(forPixelSize pixels: Int) -> String? {
    switch pixels {
    case 16:
        return "icp4"
    case 32:
        return "icp5"
    case 64:
        return "icp6"
    case 128:
        return "ic07"
    case 256:
        return "ic08"
    case 512:
        return "ic09"
    case 1024:
        return "ic10"
    default:
        return nil
    }
}

private func writeICNS(chunks: [(type: String, data: Data)], to outputURL: URL) throws {
    var data = Data()
    data.append(contentsOf: "icns".utf8)

    let totalLength = UInt32(8 + chunks.reduce(0) { $0 + 8 + $1.data.count })
    appendBigEndian(totalLength, to: &data)

    for chunk in chunks {
        guard let typeData = chunk.type.data(using: .ascii),
              typeData.count == 4
        else {
            throw NSError(domain: "DuckWhispererIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ICNS chunk type \(chunk.type)."])
        }

        data.append(typeData)
        appendBigEndian(UInt32(8 + chunk.data.count), to: &data)
        data.append(chunk.data)
    }

    try data.write(to: outputURL)
}

private func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { bytes in
        data.append(contentsOf: bytes)
    }
}

private func drawDuckWhispererIcon(in rect: NSRect) {
    let w = rect.width
    let h = rect.height

    NSColor.clear.setFill()
    rect.fill()

    let background = NSBezierPath(roundedRect: rect.insetBy(dx: w * 0.045, dy: h * 0.045), xRadius: w * 0.22, yRadius: h * 0.22)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.030, green: 0.030, blue: 0.026, alpha: 1),
        NSColor(calibratedRed: 0.105, green: 0.085, blue: 0.035, alpha: 1)
    ])?.draw(in: background, angle: 270)

    let glow = NSBezierPath(ovalIn: NSRect(x: w * 0.18, y: h * 0.12, width: w * 0.64, height: h * 0.72))
    NSColor(calibratedRed: 1.0, green: 0.68, blue: 0.10, alpha: 0.18).setFill()
    glow.fill()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.26)
    shadow.shadowBlurRadius = w * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -w * 0.012)
    shadow.set()

    NSGraphicsContext.saveGraphicsState()
    let mascotScale: CGFloat = 0.82
    let transform = NSAffineTransform()
    transform.translateX(by: w * 0.50, yBy: h * 0.50)
    transform.scale(by: mascotScale)
    transform.translateX(by: -w * 0.50, yBy: -h * 0.50)
    transform.concat()
    drawIconWaves(width: w, height: h)
    drawIconMascot(width: w, height: h)
    NSGraphicsContext.restoreGraphicsState()
}

private func drawIconWaves(width w: CGFloat, height h: CGFloat) {
    let color = NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.10, alpha: 0.88)
    for x in [w * 0.22, w * 0.82] {
        let heights: [CGFloat] = [0.18, 0.31, 0.44, 0.31, 0.18]
        for (index, heightRatio) in heights.enumerated() {
            let barWidth = w * 0.030
            let barHeight = h * heightRatio
            let barX = x + CGFloat(index - 2) * w * 0.052 - barWidth / 2
            let bar = NSBezierPath(
                roundedRect: NSRect(x: barX, y: h * 0.50 - barHeight / 2, width: barWidth, height: barHeight),
                xRadius: barWidth / 2,
                yRadius: barWidth / 2
            )
            color.withAlphaComponent(index == 2 ? 0.92 : 0.72).setFill()
            bar.fill()
        }
    }
}

private func drawIconMascot(width w: CGFloat, height h: CGFloat) {
    let badgeRect = NSRect(x: w * 0.31, y: h * 0.14, width: w * 0.58, height: h * 0.72)
    let badge = NSBezierPath(ovalIn: badgeRect)
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.12, alpha: 0.18),
        NSColor(calibratedRed: 0.36, green: 0.24, blue: 0.04, alpha: 0.08)
    ])?.draw(in: badge, angle: 270)
    NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.12, alpha: 0.80).setStroke()
    badge.lineWidth = max(4, w * 0.024)
    badge.stroke()

    let neck = NSBezierPath()
    neck.move(to: NSPoint(x: w * 0.44, y: h * 0.20))
    neck.curve(
        to: NSPoint(x: w * 0.47, y: h * 0.59),
        controlPoint1: NSPoint(x: w * 0.36, y: h * 0.32),
        controlPoint2: NSPoint(x: w * 0.36, y: h * 0.51)
    )
    neck.curve(
        to: NSPoint(x: w * 0.67, y: h * 0.54),
        controlPoint1: NSPoint(x: w * 0.54, y: h * 0.67),
        controlPoint2: NSPoint(x: w * 0.64, y: h * 0.64)
    )
    neck.curve(
        to: NSPoint(x: w * 0.62, y: h * 0.20),
        controlPoint1: NSPoint(x: w * 0.69, y: h * 0.39),
        controlPoint2: NSPoint(x: w * 0.65, y: h * 0.27)
    )
    neck.curve(
        to: NSPoint(x: w * 0.44, y: h * 0.20),
        controlPoint1: NSPoint(x: w * 0.58, y: h * 0.12),
        controlPoint2: NSPoint(x: w * 0.49, y: h * 0.12)
    )
    neck.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.91, alpha: 1),
        NSColor(calibratedRed: 0.99, green: 0.84, blue: 0.46, alpha: 1)
    ])?.draw(in: neck, angle: 90)

    let head = NSBezierPath(ovalIn: NSRect(x: w * 0.47, y: h * 0.52, width: w * 0.38, height: h * 0.34))
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.91, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.44, alpha: 1)
    ])?.draw(in: head, angle: 85)

    let beak = NSBezierPath()
    beak.move(to: NSPoint(x: w * 0.80, y: h * 0.70))
    beak.curve(
        to: NSPoint(x: w * 1.04, y: h * 0.64),
        controlPoint1: NSPoint(x: w * 0.90, y: h * 0.78),
        controlPoint2: NSPoint(x: w * 1.00, y: h * 0.75)
    )
    beak.curve(
        to: NSPoint(x: w * 0.80, y: h * 0.54),
        controlPoint1: NSPoint(x: w * 0.99, y: h * 0.52),
        controlPoint2: NSPoint(x: w * 0.90, y: h * 0.49)
    )
    beak.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.64, blue: 0.10, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.03, alpha: 1)
    ])?.draw(in: beak, angle: 0)

    let eye = NSBezierPath(ovalIn: NSRect(x: w * 0.62, y: h * 0.66, width: w * 0.052, height: h * 0.070))
    NSColor(calibratedWhite: 0.04, alpha: 1).setFill()
    eye.fill()

    let glint = NSBezierPath(ovalIn: NSRect(x: w * 0.637, y: h * 0.704, width: w * 0.014, height: h * 0.016))
    NSColor.white.withAlphaComponent(0.92).setFill()
    glint.fill()

    let smile = NSBezierPath()
    smile.lineWidth = max(1.4, w * 0.014)
    smile.lineCapStyle = .round
    smile.move(to: NSPoint(x: w * 0.73, y: h * 0.59))
    smile.curve(
        to: NSPoint(x: w * 0.79, y: h * 0.59),
        controlPoint1: NSPoint(x: w * 0.745, y: h * 0.55),
        controlPoint2: NSPoint(x: w * 0.775, y: h * 0.55)
    )
    NSColor(calibratedWhite: 0.06, alpha: 0.92).setStroke()
    smile.stroke()
}
