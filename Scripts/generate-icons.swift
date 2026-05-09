#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count >= 3 else {
    fatalError("Usage: generate-icons.swift <resources-dir> <source-png>")
}

let resourcesURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[2])
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let fileManager = FileManager.default

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fatalError("Could not read source icon: \(sourceURL.path)")
}

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconSpecs: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for spec in iconSpecs {
    let image = resizedIcon(from: sourceImage, pixels: spec.pixels)
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render \(spec.name)")
    }

    try png.write(to: iconsetURL.appendingPathComponent(spec.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    "-o", resourcesURL.appendingPathComponent("AppIcon.icns").path,
    iconsetURL.path
]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed")
}

try? fileManager.removeItem(at: iconsetURL)

func resizedIcon(from source: NSImage, pixels: Int) -> NSImage {
    let targetSize = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: targetSize)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let clipInset = CGFloat(pixels) * 0.035
    let clipRect = NSRect(origin: .zero, size: targetSize).insetBy(dx: clipInset, dy: clipInset)
    let clipPath = NSBezierPath(
        roundedRect: clipRect,
        xRadius: CGFloat(pixels) * 0.18,
        yRadius: CGFloat(pixels) * 0.18
    )
    clipPath.addClip()

    source.draw(
        in: NSRect(origin: .zero, size: targetSize),
        from: NSRect(origin: .zero, size: source.size),
        operation: .copy,
        fraction: 1.0
    )
    image.unlockFocus()
    return image
}
