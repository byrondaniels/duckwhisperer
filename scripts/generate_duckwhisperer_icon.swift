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
    for side in [-1.0, 1.0] {
        let direction = CGFloat(side)
        for index in 0..<2 {
            let offset = CGFloat(index)
            let center = NSPoint(x: w * 0.50 + direction * w * (0.14 + offset * 0.05), y: h * 0.50)
            let radius = w * (0.14 + offset * 0.08)
            let path = NSBezierPath()
            path.lineWidth = max(3, w * (0.028 - offset * 0.004))
            path.lineCapStyle = .round
            path.move(to: NSPoint(x: center.x + direction * radius * 0.20, y: center.y + radius * 0.66))
            path.curve(
                to: NSPoint(x: center.x + direction * radius * 0.20, y: center.y - radius * 0.66),
                controlPoint1: NSPoint(x: center.x + direction * radius, y: center.y + radius * 0.42),
                controlPoint2: NSPoint(x: center.x + direction * radius, y: center.y - radius * 0.42)
            )
            color.withAlphaComponent(0.88 - offset * 0.18).setStroke()
            path.stroke()
        }
    }
}

private func drawIconMascot(width w: CGFloat, height h: CGFloat) {
    let ground = NSBezierPath(ovalIn: NSRect(x: w * 0.27, y: h * 0.19, width: w * 0.50, height: h * 0.10))
    NSColor.black.withAlphaComponent(0.20).setFill()
    ground.fill()

    let body = NSBezierPath()
    body.move(to: NSPoint(x: w * 0.25, y: h * 0.38))
    body.curve(
        to: NSPoint(x: w * 0.44, y: h * 0.24),
        controlPoint1: NSPoint(x: w * 0.27, y: h * 0.29),
        controlPoint2: NSPoint(x: w * 0.34, y: h * 0.24)
    )
    body.line(to: NSPoint(x: w * 0.58, y: h * 0.24))
    body.curve(
        to: NSPoint(x: w * 0.78, y: h * 0.40),
        controlPoint1: NSPoint(x: w * 0.70, y: h * 0.25),
        controlPoint2: NSPoint(x: w * 0.77, y: h * 0.31)
    )
    body.curve(
        to: NSPoint(x: w * 0.68, y: h * 0.53),
        controlPoint1: NSPoint(x: w * 0.77, y: h * 0.47),
        controlPoint2: NSPoint(x: w * 0.73, y: h * 0.51)
    )
    body.curve(
        to: NSPoint(x: w * 0.44, y: h * 0.54),
        controlPoint1: NSPoint(x: w * 0.58, y: h * 0.57),
        controlPoint2: NSPoint(x: w * 0.49, y: h * 0.55)
    )
    body.curve(
        to: NSPoint(x: w * 0.25, y: h * 0.38),
        controlPoint1: NSPoint(x: w * 0.33, y: h * 0.54),
        controlPoint2: NSPoint(x: w * 0.26, y: h * 0.49)
    )
    body.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.91, alpha: 1),
        NSColor(calibratedWhite: 0.82, alpha: 1)
    ])?.draw(in: body, angle: 90)
    NSColor.white.withAlphaComponent(0.48).setStroke()
    body.lineWidth = max(1, w * 0.008)
    body.stroke()

    let wing = NSBezierPath()
    wing.move(to: NSPoint(x: w * 0.44, y: h * 0.38))
    wing.curve(
        to: NSPoint(x: w * 0.61, y: h * 0.34),
        controlPoint1: NSPoint(x: w * 0.50, y: h * 0.45),
        controlPoint2: NSPoint(x: w * 0.58, y: h * 0.43)
    )
    wing.curve(
        to: NSPoint(x: w * 0.48, y: h * 0.30),
        controlPoint1: NSPoint(x: w * 0.58, y: h * 0.28),
        controlPoint2: NSPoint(x: w * 0.52, y: h * 0.28)
    )
    wing.curve(
        to: NSPoint(x: w * 0.44, y: h * 0.38),
        controlPoint1: NSPoint(x: w * 0.44, y: h * 0.31),
        controlPoint2: NSPoint(x: w * 0.42, y: h * 0.35)
    )
    wing.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.88, blue: 0.40, alpha: 0.96),
        NSColor(calibratedRed: 0.98, green: 0.63, blue: 0.08, alpha: 0.96)
    ])?.draw(in: wing, angle: 90)

    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: w * 0.27, y: h * 0.42))
    tail.line(to: NSPoint(x: w * 0.14, y: h * 0.54))
    tail.line(to: NSPoint(x: w * 0.22, y: h * 0.35))
    tail.close()
    NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.88, alpha: 1).setFill()
    tail.fill()

    let neck = NSBezierPath()
    neck.move(to: NSPoint(x: w * 0.59, y: h * 0.50))
    neck.curve(
        to: NSPoint(x: w * 0.64, y: h * 0.66),
        controlPoint1: NSPoint(x: w * 0.60, y: h * 0.57),
        controlPoint2: NSPoint(x: w * 0.61, y: h * 0.62)
    )
    neck.line(to: NSPoint(x: w * 0.72, y: h * 0.63))
    neck.curve(
        to: NSPoint(x: w * 0.67, y: h * 0.47),
        controlPoint1: NSPoint(x: w * 0.72, y: h * 0.55),
        controlPoint2: NSPoint(x: w * 0.70, y: h * 0.50)
    )
    neck.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.42, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.68, blue: 0.10, alpha: 1)
    ])?.draw(in: neck, angle: 90)

    let head = NSBezierPath(ovalIn: NSRect(x: w * 0.56, y: h * 0.57, width: w * 0.26, height: h * 0.24))
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.38, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.66, blue: 0.06, alpha: 1)
    ])?.draw(in: head, angle: 90)

    let beak = NSBezierPath()
    beak.move(to: NSPoint(x: w * 0.78, y: h * 0.67))
    beak.curve(
        to: NSPoint(x: w * 0.92, y: h * 0.63),
        controlPoint1: NSPoint(x: w * 0.84, y: h * 0.70),
        controlPoint2: NSPoint(x: w * 0.89, y: h * 0.68)
    )
    beak.curve(
        to: NSPoint(x: w * 0.78, y: h * 0.59),
        controlPoint1: NSPoint(x: w * 0.88, y: h * 0.58),
        controlPoint2: NSPoint(x: w * 0.83, y: h * 0.57)
    )
    beak.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.64, blue: 0.10, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.03, alpha: 1)
    ])?.draw(in: beak, angle: 0)

    let crest = NSBezierPath()
    crest.move(to: NSPoint(x: w * 0.62, y: h * 0.76))
    crest.curve(
        to: NSPoint(x: w * 0.54, y: h * 0.91),
        controlPoint1: NSPoint(x: w * 0.58, y: h * 0.82),
        controlPoint2: NSPoint(x: w * 0.56, y: h * 0.88)
    )
    crest.curve(
        to: NSPoint(x: w * 0.69, y: h * 0.78),
        controlPoint1: NSPoint(x: w * 0.65, y: h * 0.90),
        controlPoint2: NSPoint(x: w * 0.69, y: h * 0.85)
    )
    crest.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.62, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.10, alpha: 1)
    ])?.draw(in: crest, angle: 90)

    let eye = NSBezierPath(ovalIn: NSRect(x: w * 0.67, y: h * 0.68, width: w * 0.042, height: h * 0.055))
    NSColor(calibratedWhite: 0.04, alpha: 1).setFill()
    eye.fill()

    let glint = NSBezierPath(ovalIn: NSRect(x: w * 0.681, y: h * 0.708, width: w * 0.012, height: h * 0.014))
    NSColor.white.withAlphaComponent(0.92).setFill()
    glint.fill()

    let smile = NSBezierPath()
    smile.lineWidth = max(1.4, w * 0.014)
    smile.lineCapStyle = .round
    smile.move(to: NSPoint(x: w * 0.72, y: h * 0.63))
    smile.curve(
        to: NSPoint(x: w * 0.76, y: h * 0.63),
        controlPoint1: NSPoint(x: w * 0.73, y: h * 0.61),
        controlPoint2: NSPoint(x: w * 0.75, y: h * 0.61)
    )
    NSColor(calibratedWhite: 0.06, alpha: 0.92).setStroke()
    smile.stroke()
}
