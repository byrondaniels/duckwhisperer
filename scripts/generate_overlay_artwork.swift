import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: swift generate_overlay_artwork.swift input.png output.png\n", stderr)
    exit(EXIT_FAILURE)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard
    let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
else {
    fputs("Could not read \(inputURL.path)\n", stderr)
    exit(EXIT_FAILURE)
}

let sourceWidth = image.width
let sourceHeight = image.height
let sourceBytesPerRow = sourceWidth * 4
var sourcePixels = [UInt8](repeating: 0, count: sourceHeight * sourceBytesPerRow)

guard let sourceContext = CGContext(
    data: &sourcePixels,
    width: sourceWidth,
    height: sourceHeight,
    bitsPerComponent: 8,
    bytesPerRow: sourceBytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Could not allocate source bitmap\n", stderr)
    exit(EXIT_FAILURE)
}

sourceContext.draw(image, in: CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))

let cropX = 103
let cropY = 32
let outputWidth = 300
let outputHeight = 318
let outputBytesPerRow = outputWidth * 4
var outputPixels = [UInt8](repeating: 0, count: outputHeight * outputBytesPerRow)

func inEllipse(x: CGFloat, y: CGFloat, centerX: CGFloat, centerY: CGFloat, radiusX: CGFloat, radiusY: CGFloat) -> Bool {
    let dx = (x - centerX) / radiusX
    let dy = (y - centerY) / radiusY
    return dx * dx + dy * dy <= 1
}

func edgeFade(x: Int, y: Int, width: Int, height: Int) -> CGFloat {
    let edge = min(min(x, width - 1 - x), min(y, height - 1 - y))
    return min(1, max(0, CGFloat(edge) / 14))
}

for y in 0..<outputHeight {
    for x in 0..<outputWidth {
        let sourceX = cropX + x
        let sourceY = cropY + y
        guard sourceX >= 0, sourceX < sourceWidth, sourceY >= 0, sourceY < sourceHeight else {
            continue
        }

        let sourceIndex = sourceY * sourceBytesPerRow + sourceX * 4
        let red = CGFloat(sourcePixels[sourceIndex]) / 255
        let green = CGFloat(sourcePixels[sourceIndex + 1]) / 255
        let blue = CGFloat(sourcePixels[sourceIndex + 2]) / 255
        let maxChannel = max(red, max(green, blue))
        let minChannel = min(red, min(green, blue))
        let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0
        let px = CGFloat(x)
        let py = CGFloat(y)

        let headMask = inEllipse(x: px, y: py, centerX: 160, centerY: 89, radiusX: 106, radiusY: 88)
        let beakMask = inEllipse(x: px, y: py, centerX: 258, centerY: 129, radiusX: 94, radiusY: 49)
        let neckMask = inEllipse(x: px, y: py, centerX: 145, centerY: 214, radiusX: 82, radiusY: 112)
        let ringOuter = inEllipse(x: px, y: py, centerX: 153, centerY: 173, radiusX: 157, radiusY: 160)
        let ringInner = inEllipse(x: px, y: py, centerX: 153, centerY: 173, radiusX: 136, radiusY: 141)

        let warmGold = red > 0.22 && green > 0.14 && red > blue * 1.45 && green > blue * 1.08
        let creamDuck = red > 0.46 && green > 0.36 && blue > 0.17 && red >= green * 0.90
        let orangeBeak = red > 0.48 && green > 0.20 && blue < 0.25 && saturation > 0.32
        let visibleRing = ringOuter && !ringInner && warmGold
        let darkDetail = (headMask || beakMask) && maxChannel > 0.025 && maxChannel < 0.34 && saturation < 0.58
        let duckOrBeak = (headMask || neckMask || beakMask) && (creamDuck || orangeBeak || warmGold || darkDetail)

        var alpha: CGFloat = 0
        if duckOrBeak || visibleRing {
            alpha = 1
        } else if warmGold && maxChannel > 0.17 {
            alpha = min(0.70, max(0, (maxChannel - 0.17) * 1.9))
        }

        alpha *= edgeFade(x: x, y: y, width: outputWidth, height: outputHeight)

        if alpha >= 0.03 {
            let outputIndex = y * outputBytesPerRow + x * 4
            outputPixels[outputIndex] = UInt8(max(0, min(255, red * alpha * 255)))
            outputPixels[outputIndex + 1] = UInt8(max(0, min(255, green * alpha * 255)))
            outputPixels[outputIndex + 2] = UInt8(max(0, min(255, blue * alpha * 255)))
            outputPixels[outputIndex + 3] = UInt8(max(0, min(255, alpha * 255)))
        }
    }
}

guard
    let provider = CGDataProvider(data: Data(outputPixels) as CFData),
    let outputImage = CGImage(
        width: outputWidth,
        height: outputHeight,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: outputBytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    ),
    let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else {
    fputs("Could not create output PNG\n", stderr)
    exit(EXIT_FAILURE)
}

CGImageDestinationAddImage(destination, outputImage, nil)
if !CGImageDestinationFinalize(destination) {
    fputs("Could not write \(outputURL.path)\n", stderr)
    exit(EXIT_FAILURE)
}
