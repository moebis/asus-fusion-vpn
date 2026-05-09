import AppKit

enum IconFactory {
    static func menuBarIcon(state: VPNConnectionState) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            drawSolidIcon(in: rect, opacity: opacity(for: state))
            return true
        }

        image.isTemplate = true
        return image
    }

    private static func drawSolidIcon(in rect: NSRect, opacity: CGFloat) {
        guard opacity < 1 else {
            drawShape(in: rect)
            return
        }

        let mask = NSImage(size: rect.size, flipped: false) { maskRect in
            drawShape(in: maskRect)
            return true
        }
        mask.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity)
    }

    private static func drawShape(in rect: NSRect) {
        let points = [
            NSPoint(x: rect.minX + 5.0, y: rect.minY + 4.4),
            NSPoint(x: rect.midX, y: rect.maxY - 4.2),
            NSPoint(x: rect.maxX - 5.0, y: rect.minY + 4.4)
        ]

        NSColor.black.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 2.8
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: points[0])
        path.line(to: points[1])
        path.line(to: points[2])
        path.stroke()
    }

    private static func opacity(for state: VPNConnectionState) -> CGFloat {
        switch state {
        case .connected, .connecting:
            1.0
        case .disconnected, .unknown:
            0.25
        }
    }
}
