#!/usr/bin/env swift
import AppKit

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: generate_dmg_background.swift <output.png>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 600, height: 420)

let image = NSImage(size: size)
image.lockFocus()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.15, alpha: 1),
    NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1)
])!
gradient.draw(in: NSRect(origin: .zero, size: size), angle: -90)

let title = "Install DuckWhisperer"
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 26),
    .foregroundColor: NSColor.white.withAlphaComponent(0.95)
]
let titleSize = title.size(withAttributes: titleAttrs)
title.draw(at: NSPoint(x: (size.width - titleSize.width) / 2, y: 358), withAttributes: titleAttrs)

let subtitle = "Drag the duck onto Applications"
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14),
    .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.10, alpha: 0.85)
]
let subSize = subtitle.size(withAttributes: subAttrs)
subtitle.draw(at: NSPoint(x: (size.width - subSize.width) / 2, y: 326), withAttributes: subAttrs)

let arrowColor = NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.10, alpha: 0.90)
let arrowY: CGFloat = 200
let arrowStartX: CGFloat = 240
let arrowEndX: CGFloat = 360

let shaft = NSBezierPath()
shaft.move(to: NSPoint(x: arrowStartX, y: arrowY))
shaft.line(to: NSPoint(x: arrowEndX - 4, y: arrowY))
shaft.lineWidth = 5
shaft.lineCapStyle = .round
arrowColor.setStroke()
shaft.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: arrowEndX + 14, y: arrowY))
head.line(to: NSPoint(x: arrowEndX - 6, y: arrowY + 13))
head.line(to: NSPoint(x: arrowEndX - 6, y: arrowY - 13))
head.close()
arrowColor.setFill()
head.fill()

let hint = "Then open Applications and right-click DuckWhisperer once to allow it."
let hintAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11),
    .foregroundColor: NSColor.white.withAlphaComponent(0.5)
]
let hintSize = hint.size(withAttributes: hintAttrs)
hint.draw(at: NSPoint(x: (size.width - hintSize.width) / 2, y: 40), withAttributes: hintAttrs)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fputs("Failed to render PNG\n", stderr)
    exit(1)
}

do {
    try png.write(to: outputURL)
} catch {
    fputs("Failed to write \(outputURL.path): \(error)\n", stderr)
    exit(1)
}
