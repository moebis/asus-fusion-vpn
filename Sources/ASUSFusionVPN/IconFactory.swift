import AppKit

enum IconFactory {
    static func menuBarIcon(state: VPNConnectionState) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            let points = [
                NSPoint(x: rect.minX + 4.7, y: rect.minY + 4.2),
                NSPoint(x: rect.midX, y: rect.maxY - 4.2),
                NSPoint(x: rect.maxX - 4.7, y: rect.minY + 4.2)
            ]

            _ = state
            NSColor.black.setStroke()
            NSColor.black.setFill()

            drawSegment(from: points[0], to: points[1])
            drawSegment(from: points[2], to: points[1])

            for point in points {
                NSBezierPath(
                    ovalIn: NSRect(x: point.x - 2.2, y: point.y - 2.2, width: 4.4, height: 4.4)
                ).fill()
            }

            return true
        }

        image.isTemplate = true
        return image
    }

    private static func drawSegment(from start: NSPoint, to end: NSPoint) {
        let path = NSBezierPath()
        path.lineWidth = 2.1
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: start)
        path.line(to: end)
        path.stroke()
    }
}
