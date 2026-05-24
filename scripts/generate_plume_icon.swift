import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift generate_plume_icon.swift /path/to/Plume.icns\n", stderr)
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
    drawPlumeIcon(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
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
            throw NSError(domain: "PlumeIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ICNS chunk type \(chunk.type)."])
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

private func drawPlumeIcon(in rect: NSRect) {
    let w = rect.width
    let h = rect.height

    NSColor.clear.setFill()
    rect.fill()

    let background = NSBezierPath(roundedRect: rect.insetBy(dx: w * 0.045, dy: h * 0.045), xRadius: w * 0.22, yRadius: h * 0.22)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.035, green: 0.095, blue: 0.105, alpha: 1),
        NSColor(calibratedRed: 0.075, green: 0.165, blue: 0.180, alpha: 1)
    ])?.draw(in: background, angle: 270)

    let glow = NSBezierPath(ovalIn: NSRect(x: w * 0.20, y: h * 0.12, width: w * 0.68, height: h * 0.68))
    NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.22, alpha: 0.16).setFill()
    glow.fill()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.26)
    shadow.shadowBlurRadius = w * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -w * 0.012)
    shadow.set()

    let feather = NSBezierPath()
    feather.move(to: NSPoint(x: w * 0.24, y: h * 0.77))
    feather.curve(
        to: NSPoint(x: w * 0.79, y: h * 0.17),
        controlPoint1: NSPoint(x: w * 0.26, y: h * 0.31),
        controlPoint2: NSPoint(x: w * 0.62, y: h * 0.10)
    )
    feather.curve(
        to: NSPoint(x: w * 0.31, y: h * 0.84),
        controlPoint1: NSPoint(x: w * 0.47, y: h * 0.20),
        controlPoint2: NSPoint(x: w * 0.20, y: h * 0.50)
    )
    feather.curve(
        to: NSPoint(x: w * 0.24, y: h * 0.77),
        controlPoint1: NSPoint(x: w * 0.28, y: h * 0.84),
        controlPoint2: NSPoint(x: w * 0.25, y: h * 0.80)
    )
    feather.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.78, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.66, blue: 0.22, alpha: 1)
    ])?.draw(in: feather, angle: 245)

    let shaft = NSBezierPath()
    shaft.lineWidth = max(3, w * 0.045)
    shaft.lineCapStyle = .round
    shaft.move(to: NSPoint(x: w * 0.26, y: h * 0.81))
    shaft.line(to: NSPoint(x: w * 0.78, y: h * 0.17))
    NSColor(calibratedRed: 0.58, green: 0.34, blue: 0.12, alpha: 0.44).setStroke()
    shaft.stroke()

    let notch = NSBezierPath()
    notch.move(to: NSPoint(x: w * 0.43, y: h * 0.62))
    notch.line(to: NSPoint(x: w * 0.23, y: h * 0.58))
    notch.line(to: NSPoint(x: w * 0.47, y: h * 0.53))
    notch.close()
    NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.13, alpha: 0.44).setFill()
    notch.fill()

    let highlight = NSBezierPath(ovalIn: NSRect(x: w * 0.51, y: h * 0.50, width: w * 0.08, height: h * 0.20))
    NSColor(calibratedWhite: 1, alpha: 0.22).setFill()
    highlight.fill()
}
