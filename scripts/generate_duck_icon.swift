import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift generate_duck_icon.swift /path/to/DuckWhisperer.icns\n", stderr)
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
    drawDuckIcon(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
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
            throw NSError(domain: "DuckIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ICNS chunk type \(chunk.type)."])
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

private func drawDuckIcon(in rect: NSRect) {
    let w = rect.width
    let h = rect.height

    NSColor.clear.setFill()
    rect.fill()

    let background = NSBezierPath(roundedRect: rect.insetBy(dx: w * 0.045, dy: h * 0.045), xRadius: w * 0.22, yRadius: h * 0.22)
    NSColor(calibratedRed: 0.07, green: 0.18, blue: 0.20, alpha: 1).setFill()
    background.fill()

    let water = NSBezierPath(roundedRect: NSRect(x: w * 0.16, y: h * 0.18, width: w * 0.68, height: h * 0.15), xRadius: h * 0.075, yRadius: h * 0.075)
    NSColor(calibratedRed: 0.15, green: 0.58, blue: 0.66, alpha: 1).setFill()
    water.fill()

    let shadow = NSBezierPath(ovalIn: NSRect(x: w * 0.25, y: h * 0.24, width: w * 0.45, height: h * 0.075))
    NSColor(calibratedWhite: 0, alpha: 0.20).setFill()
    shadow.fill()

    let duckYellow = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.20, alpha: 1)
    let duckGold = NSColor(calibratedRed: 0.94, green: 0.60, blue: 0.10, alpha: 1)
    let beakOrange = NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.12, alpha: 1)

    let body = NSBezierPath(ovalIn: NSRect(x: w * 0.19, y: h * 0.30, width: w * 0.48, height: h * 0.29))
    duckYellow.setFill()
    body.fill()

    let chest = NSBezierPath(ovalIn: NSRect(x: w * 0.41, y: h * 0.31, width: w * 0.30, height: h * 0.25))
    duckYellow.setFill()
    chest.fill()

    let head = NSBezierPath(ovalIn: NSRect(x: w * 0.54, y: h * 0.52, width: w * 0.24, height: h * 0.24))
    duckYellow.setFill()
    head.fill()

    let beak = NSBezierPath()
    beak.move(to: NSPoint(x: w * 0.75, y: h * 0.61))
    beak.line(to: NSPoint(x: w * 0.91, y: h * 0.56))
    beak.line(to: NSPoint(x: w * 0.75, y: h * 0.51))
    beak.close()
    beakOrange.setFill()
    beak.fill()

    let wing = NSBezierPath()
    wing.move(to: NSPoint(x: w * 0.31, y: h * 0.44))
    wing.curve(
        to: NSPoint(x: w * 0.55, y: h * 0.43),
        controlPoint1: NSPoint(x: w * 0.36, y: h * 0.57),
        controlPoint2: NSPoint(x: w * 0.50, y: h * 0.57)
    )
    wing.curve(
        to: NSPoint(x: w * 0.31, y: h * 0.44),
        controlPoint1: NSPoint(x: w * 0.51, y: h * 0.33),
        controlPoint2: NSPoint(x: w * 0.38, y: h * 0.31)
    )
    duckGold.setFill()
    wing.fill()

    NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: w * 0.665, y: h * 0.635, width: w * 0.035, height: h * 0.035)).fill()

    let highlight = NSBezierPath(ovalIn: NSRect(x: w * 0.59, y: h * 0.66, width: w * 0.055, height: h * 0.035))
    NSColor(calibratedWhite: 1, alpha: 0.30).setFill()
    highlight.fill()
}
