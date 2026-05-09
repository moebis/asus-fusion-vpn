#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count >= 3 else {
    fatalError("Usage: generate-dmg-background.swift <output-png> <source-icon-png>")
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let sourceIconURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard NSImage(contentsOf: sourceIconURL) != nil else {
    fatalError("Could not read source icon: \(sourceIconURL.path)")
}

let size = NSSize(width: 900, height: 500)
let image = NSImage(size: size)
image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.15, alpha: 1.0),
    NSColor(calibratedRed: 0.14, green: 0.13, blue: 0.19, alpha: 1.0)
])!
background.draw(in: bounds, angle: 315)

let glowColor = NSColor(calibratedRed: 0.06, green: 0.77, blue: 0.95, alpha: 0.18)
glowColor.setFill()
NSBezierPath(ovalIn: NSRect(x: 116, y: 92, width: 250, height: 250)).fill()

drawText(
    "ASUS Fusion VPN",
    in: NSRect(x: 0, y: 398, width: size.width, height: 42),
    font: .systemFont(ofSize: 28, weight: .bold),
    color: .white,
    alignment: .center
)

drawText(
    "Drag ASUS Fusion VPN to Applications",
    in: NSRect(x: 0, y: 366, width: size.width, height: 24),
    font: .systemFont(ofSize: 15, weight: .medium),
    color: NSColor(calibratedWhite: 0.78, alpha: 1.0),
    alignment: .center
)

drawArrow(from: NSPoint(x: 360, y: 252), to: NSPoint(x: 540, y: 252))

let footerColor = NSColor(calibratedWhite: 0.62, alpha: 1.0)
drawText(
    "LAN-only SSH control for ASUSWRT VPN Fusion",
    in: NSRect(x: 0, y: 66, width: size.width, height: 22),
    font: .systemFont(ofSize: 13, weight: .regular),
    color: footerColor,
    alignment: .center
)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Could not render DMG background.")
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL)

func drawText(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    text.draw(in: rect, withAttributes: attributes)
}

func drawArrow(from start: NSPoint, to end: NSPoint) {
    let path = NSBezierPath()
    path.move(to: start)
    path.curve(
        to: end,
        controlPoint1: NSPoint(x: start.x + 42, y: start.y + 34),
        controlPoint2: NSPoint(x: end.x - 42, y: end.y + 34)
    )
    path.lineWidth = 5
    NSColor(calibratedRed: 0.08, green: 0.80, blue: 0.95, alpha: 0.85).setStroke()
    path.stroke()

    let head = NSBezierPath()
    head.move(to: end)
    head.line(to: NSPoint(x: end.x - 18, y: end.y + 12))
    head.line(to: NSPoint(x: end.x - 13, y: end.y - 10))
    head.close()
    NSColor(calibratedRed: 0.08, green: 0.80, blue: 0.95, alpha: 0.9).setFill()
    head.fill()
}
