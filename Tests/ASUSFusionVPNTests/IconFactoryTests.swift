import AppKit
import Testing
@testable import ASUSFusionVPN

@MainActor
@Test func menuBarIconsAreCachedTemplateImages() {
    for state in [VPNConnectionState.connected, .connecting, .disconnected, .unknown] {
        let image = IconFactory.menuBarIcon(state: state)
        #expect(image.isTemplate)
        #expect(image === IconFactory.menuBarIcon(state: state))
    }
}

@MainActor
@Test func connectedMenuBarIconUsesFullOpacityTemplatePixels() throws {
    let alphas = try renderedAlphaValues(from: IconFactory.menuBarIcon(state: .connected))

    #expect(alphas.max() == 255)
}

private let lockBodySamplePoint = NSPoint(x: IconFactory.lockBody.minX + 1, y: IconFactory.lockBody.minY + 1)

@MainActor
@Test func connectedMenuBarIconKnocksOutLockFromSolidShield() throws {
    let alphaGrid = try renderedAlphaGrid(from: IconFactory.menuBarIcon(state: .connected))

    #expect(alpha(in: alphaGrid, at: lockBodySamplePoint) < 40)
    // Shield body below the lock stays solid.
    #expect(alpha(in: alphaGrid, at: NSPoint(x: 9, y: 3)) > 240)
}

@MainActor
@Test func connectingMenuBarIconDrawsSolidLock() throws {
    let alphaGrid = try renderedAlphaGrid(from: IconFactory.menuBarIcon(state: .connecting))

    #expect(alpha(in: alphaGrid, at: lockBodySamplePoint) > 240)
}

@MainActor
@Test func disconnectedMenuBarIconUsesReducedOpacityTemplatePixels() throws {
    let alphas = try renderedAlphaValues(from: IconFactory.menuBarIcon(state: .disconnected))

    #expect((alphas.max() ?? 0) < 180)
    #expect((alphas.max() ?? 0) > 0)
}

@MainActor
@Test func disconnectedMenuBarIconDoesNotStackOpacityAtShapeOverlaps() throws {
    let alphas = try renderedAlphaValues(from: IconFactory.menuBarIcon(state: .disconnected))
    let strongest = alphas.max() ?? 0

    #expect(strongest <= Int((255 * 0.42).rounded()) + 2)
}

@MainActor
@Test func unknownMenuBarIconOmitsLock() throws {
    let alphaGrid = try renderedAlphaGrid(from: IconFactory.menuBarIcon(state: .unknown))

    #expect(alpha(in: alphaGrid, at: lockBodySamplePoint) == 0)
}

@MainActor
private func renderedAlphaValues(from image: NSImage) throws -> [Int] {
    try renderedAlphaGrid(from: image).flatMap { $0 }
}

@MainActor
private func renderedAlphaGrid(from image: NSImage) throws -> [[Int]] {
    let size = IconFactory.menuBarIconSize
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

    return (0..<Int(size.height)).map { y in
        (0..<Int(size.width)).compactMap { x in
            representation.colorAt(x: x, y: y).map { Int(round($0.alphaComponent * 255)) }
        }
    }
}

/// Reads the alpha at a point in the icon's bottom-left-origin coordinate space.
private func alpha(in alphaGrid: [[Int]], at point: NSPoint) -> Int {
    alphaGrid[alphaGrid.count - 1 - Int(point.y)][Int(point.x)]
}

private struct TestError: Error {
    let message: String
}
