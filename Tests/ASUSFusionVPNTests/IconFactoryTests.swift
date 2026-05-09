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
@Test func connectedMenuBarIconIncludesNodePads() throws {
    let image = IconFactory.menuBarIcon(state: .connected)
    let alphaGrid = try renderedAlphaGrid(from: image)

    #expect(opaquePixelCount(in: alphaGrid, centerX: 5, centerY: 15) >= 16)
    #expect(opaquePixelCount(in: alphaGrid, centerX: 10, centerY: 4) >= 16)
    #expect(opaquePixelCount(in: alphaGrid, centerX: 15, centerY: 15) >= 16)
}

@MainActor
private func renderedAlphaValues(from image: NSImage) throws -> [Int] {
    try renderedAlphaGrid(from: image).flatMap { $0 }
}

@MainActor
private func renderedAlphaGrid(from image: NSImage) throws -> [[Int]] {
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

    return (0..<Int(size.height)).map { y in
        (0..<Int(size.width)).compactMap { x in
            representation.colorAt(x: x, y: y).map { Int(round($0.alphaComponent * 255)) }
        }
    }
}

private func opaquePixelCount(in alphaGrid: [[Int]], centerX: Int, centerY: Int) -> Int {
    let yRange = max(0, centerY - 2)...min(alphaGrid.count - 1, centerY + 2)
    let xRange = max(0, centerX - 2)...min((alphaGrid.first?.count ?? 1) - 1, centerX + 2)

    return yRange.reduce(0) { count, y in
        count + xRange.filter { alphaGrid[y][$0] > 240 }.count
    }
}

private struct TestError: Error {
    let message: String
}
