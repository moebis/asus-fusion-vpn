import AppKit
import Testing
@testable import ASUSFusionVPN

@MainActor
@Test func connectedMenuBarIconUsesFullOpacityTemplatePixels() throws {
    let image = IconFactory.menuBarIcon(state: .connected)
    let alphas = try renderedAlphaValues(from: image)

    #expect(alphas.max() == 255)
}

@MainActor
@Test func disconnectedMenuBarIconUsesReducedOpacityTemplatePixels() throws {
    let image = IconFactory.menuBarIcon(state: .disconnected)
    let alphas = try renderedAlphaValues(from: image)

    #expect((alphas.max() ?? 0) < 180)
    #expect((alphas.max() ?? 0) > 0)
}

@MainActor
@Test func disconnectedMenuBarIconDoesNotStackOpacityAtShapeOverlaps() throws {
    let image = IconFactory.menuBarIcon(state: .disconnected)
    let alphas = try renderedAlphaValues(from: image)
    let solidPixels = alphas.filter { $0 > 120 }

    #expect((solidPixels.max() ?? 0) - (solidPixels.min() ?? 0) <= 10)
}

@MainActor
private func renderedAlphaValues(from image: NSImage) throws -> [Int] {
    let size = NSSize(width: 20, height: 20)
    guard
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else {
        throw TestError(message: "Could not create bitmap representation.")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    image.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()

    return (0..<Int(size.width)).flatMap { x in
        (0..<Int(size.height)).compactMap { y in
            representation.colorAt(x: x, y: y).map { Int(round($0.alphaComponent * 255)) }
        }
    }
}

private struct TestError: Error {
    let message: String
}
