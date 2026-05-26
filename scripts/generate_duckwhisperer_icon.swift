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
        let heights: [CGFloat] = [0.20, 0.34, 0.48, 0.34, 0.20]
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
    let ground = NSBezierPath(ovalIn: NSRect(x: w * 0.34, y: h * 0.16, width: w * 0.40, height: h * 0.08))
    NSColor.black.withAlphaComponent(0.20).setFill()
    ground.fill()

    drawIconFoot(origin: NSPoint(x: w * 0.43, y: h * 0.20), width: w * 0.16, height: h * 0.045)
    drawIconFoot(origin: NSPoint(x: w * 0.55, y: h * 0.20), width: w * 0.17, height: h * 0.045)

    let raisedWing = NSBezierPath()
    raisedWing.move(to: NSPoint(x: w * 0.58, y: h * 0.43))
    raisedWing.curve(
        to: NSPoint(x: w * 0.86, y: h * 0.66),
        controlPoint1: NSPoint(x: w * 0.67, y: h * 0.54),
        controlPoint2: NSPoint(x: w * 0.78, y: h * 0.61)
    )
    raisedWing.curve(
        to: NSPoint(x: w * 0.72, y: h * 0.40),
        controlPoint1: NSPoint(x: w * 0.89, y: h * 0.51),
        controlPoint2: NSPoint(x: w * 0.82, y: h * 0.41)
    )
    raisedWing.curve(
        to: NSPoint(x: w * 0.58, y: h * 0.43),
        controlPoint1: NSPoint(x: w * 0.67, y: h * 0.40),
        controlPoint2: NSPoint(x: w * 0.62, y: h * 0.40)
    )
    raisedWing.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.74, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.16, alpha: 1)
    ])?.draw(in: raisedWing, angle: 55)

    let body = NSBezierPath()
    body.move(to: NSPoint(x: w * 0.33, y: h * 0.34))
    body.curve(
        to: NSPoint(x: w * 0.48, y: h * 0.21),
        controlPoint1: NSPoint(x: w * 0.34, y: h * 0.25),
        controlPoint2: NSPoint(x: w * 0.39, y: h * 0.20)
    )
    body.curve(
        to: NSPoint(x: w * 0.70, y: h * 0.36),
        controlPoint1: NSPoint(x: w * 0.62, y: h * 0.20),
        controlPoint2: NSPoint(x: w * 0.70, y: h * 0.27)
    )
    body.curve(
        to: NSPoint(x: w * 0.60, y: h * 0.55),
        controlPoint1: NSPoint(x: w * 0.70, y: h * 0.48),
        controlPoint2: NSPoint(x: w * 0.65, y: h * 0.54)
    )
    body.curve(
        to: NSPoint(x: w * 0.33, y: h * 0.34),
        controlPoint1: NSPoint(x: w * 0.43, y: h * 0.56),
        controlPoint2: NSPoint(x: w * 0.31, y: h * 0.48)
    )
    body.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.91, alpha: 1),
        NSColor(calibratedRed: 0.99, green: 0.84, blue: 0.47, alpha: 1)
    ])?.draw(in: body, angle: 90)
    NSColor.white.withAlphaComponent(0.48).setStroke()
    body.lineWidth = max(1, w * 0.008)
    body.stroke()

    let wing = NSBezierPath()
    wing.move(to: NSPoint(x: w * 0.43, y: h * 0.36))
    wing.curve(
        to: NSPoint(x: w * 0.59, y: h * 0.33),
        controlPoint1: NSPoint(x: w * 0.49, y: h * 0.44),
        controlPoint2: NSPoint(x: w * 0.56, y: h * 0.42)
    )
    wing.curve(
        to: NSPoint(x: w * 0.47, y: h * 0.28),
        controlPoint1: NSPoint(x: w * 0.57, y: h * 0.28),
        controlPoint2: NSPoint(x: w * 0.52, y: h * 0.27)
    )
    wing.curve(
        to: NSPoint(x: w * 0.44, y: h * 0.38),
        controlPoint1: NSPoint(x: w * 0.44, y: h * 0.31),
        controlPoint2: NSPoint(x: w * 0.42, y: h * 0.35)
    )
    wing.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.93, blue: 0.58, alpha: 0.96),
        NSColor(calibratedRed: 0.98, green: 0.65, blue: 0.10, alpha: 0.96)
    ])?.draw(in: wing, angle: 90)

    let neck = NSBezierPath()
    neck.move(to: NSPoint(x: w * 0.53, y: h * 0.48))
    neck.curve(
        to: NSPoint(x: w * 0.54, y: h * 0.70),
        controlPoint1: NSPoint(x: w * 0.53, y: h * 0.57),
        controlPoint2: NSPoint(x: w * 0.52, y: h * 0.65)
    )
    neck.curve(
        to: NSPoint(x: w * 0.66, y: h * 0.70),
        controlPoint1: NSPoint(x: w * 0.57, y: h * 0.74),
        controlPoint2: NSPoint(x: w * 0.63, y: h * 0.74)
    )
    neck.curve(
        to: NSPoint(x: w * 0.63, y: h * 0.48),
        controlPoint1: NSPoint(x: w * 0.67, y: h * 0.61),
        controlPoint2: NSPoint(x: w * 0.66, y: h * 0.54)
    )
    neck.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.91, alpha: 1),
        NSColor(calibratedRed: 0.99, green: 0.84, blue: 0.47, alpha: 1)
    ])?.draw(in: neck, angle: 90)

    drawIconBowTie(center: NSPoint(x: w * 0.58, y: h * 0.50), scale: w * 0.10)

    let head = NSBezierPath(ovalIn: NSRect(x: w * 0.52, y: h * 0.67, width: w * 0.24, height: h * 0.21))
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.91, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.44, alpha: 1)
    ])?.draw(in: head, angle: 85)

    let beak = NSBezierPath()
    beak.move(to: NSPoint(x: w * 0.73, y: h * 0.75))
    beak.curve(
        to: NSPoint(x: w * 0.90, y: h * 0.72),
        controlPoint1: NSPoint(x: w * 0.80, y: h * 0.79),
        controlPoint2: NSPoint(x: w * 0.87, y: h * 0.77)
    )
    beak.curve(
        to: NSPoint(x: w * 0.73, y: h * 0.68),
        controlPoint1: NSPoint(x: w * 0.86, y: h * 0.66),
        controlPoint2: NSPoint(x: w * 0.79, y: h * 0.65)
    )
    beak.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.64, blue: 0.10, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.03, alpha: 1)
    ])?.draw(in: beak, angle: 0)

    let eye = NSBezierPath(ovalIn: NSRect(x: w * 0.62, y: h * 0.76, width: w * 0.040, height: h * 0.054))
    NSColor(calibratedWhite: 0.04, alpha: 1).setFill()
    eye.fill()

    let glint = NSBezierPath(ovalIn: NSRect(x: w * 0.631, y: h * 0.795, width: w * 0.011, height: h * 0.013))
    NSColor.white.withAlphaComponent(0.92).setFill()
    glint.fill()

    let smile = NSBezierPath()
    smile.lineWidth = max(1.4, w * 0.014)
    smile.lineCapStyle = .round
    smile.move(to: NSPoint(x: w * 0.70, y: h * 0.705))
    smile.curve(
        to: NSPoint(x: w * 0.735, y: h * 0.705),
        controlPoint1: NSPoint(x: w * 0.71, y: h * 0.685),
        controlPoint2: NSPoint(x: w * 0.725, y: h * 0.685)
    )
    NSColor(calibratedWhite: 0.06, alpha: 0.92).setStroke()
    smile.stroke()
}

private func drawIconFoot(origin: NSPoint, width: CGFloat, height: CGFloat) {
    let foot = NSBezierPath()
    foot.move(to: origin)
    foot.curve(
        to: NSPoint(x: origin.x + width, y: origin.y),
        controlPoint1: NSPoint(x: origin.x + width * 0.32, y: origin.y + height),
        controlPoint2: NSPoint(x: origin.x + width * 0.74, y: origin.y + height * 0.82)
    )
    foot.curve(
        to: origin,
        controlPoint1: NSPoint(x: origin.x + width * 0.70, y: origin.y - height * 0.52),
        controlPoint2: NSPoint(x: origin.x + width * 0.22, y: origin.y - height * 0.44)
    )
    foot.close()
    NSColor(calibratedRed: 1.0, green: 0.58, blue: 0.05, alpha: 1).setFill()
    foot.fill()
}

private func drawIconBowTie(center: NSPoint, scale: CGFloat) {
    let left = NSBezierPath()
    left.move(to: center)
    left.line(to: NSPoint(x: center.x - scale * 0.86, y: center.y + scale * 0.42))
    left.line(to: NSPoint(x: center.x - scale * 0.86, y: center.y - scale * 0.42))
    left.close()

    let right = NSBezierPath()
    right.move(to: center)
    right.line(to: NSPoint(x: center.x + scale * 0.86, y: center.y + scale * 0.42))
    right.line(to: NSPoint(x: center.x + scale * 0.86, y: center.y - scale * 0.42))
    right.close()

    NSColor(calibratedRed: 1.0, green: 0.63, blue: 0.08, alpha: 1).setFill()
    left.fill()
    right.fill()

    let knot = NSBezierPath(ovalIn: NSRect(x: center.x - scale * 0.20, y: center.y - scale * 0.20, width: scale * 0.40, height: scale * 0.40))
    NSColor(calibratedRed: 0.88, green: 0.39, blue: 0.02, alpha: 1).setFill()
    knot.fill()
}
