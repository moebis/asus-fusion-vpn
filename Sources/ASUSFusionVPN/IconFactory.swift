import AppKit

/// Menu bar glyph: a shield with a padlock in the middle.
///
/// - connected: solid shield with a closed lock knocked out
/// - connecting: shield outline with a closed lock, full strength
/// - disconnected: shield outline with an open lock, dimmed
/// - unknown: empty shield outline, dimmed
///
/// Images are template images, so macOS tints them for light/dark menu bars and
/// highlighted states. Each state is drawn once and cached.
enum IconFactory {
    static let menuBarIconSize = NSSize(width: 18, height: 18)
    private static let dimmedOpacity: CGFloat = 0.42

    @MainActor private static var cache: [VPNConnectionState: NSImage] = [:]

    @MainActor
    static func menuBarIcon(state: VPNConnectionState) -> NSImage {
        if let image = cache[state] {
            return image
        }
        let image = makeMenuBarIcon(state: state)
        cache[state] = image
        return image
    }

    private static func makeMenuBarIcon(state: VPNConnectionState) -> NSImage {
        let image = NSImage(size: menuBarIconSize, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(state: state, in: rect, context: context)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ASUS Fusion VPN – \(state.displayName)"
        return image
    }

    private static func draw(state: VPNConnectionState, in rect: NSRect, context: CGContext) {
        let scale = min(rect.width, rect.height) / 18
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: scale, y: scale)

        // Draw into one transparency layer so dimming applies once and overlapping
        // strokes never stack into darker pixels.
        context.setAlpha(opacity(for: state))
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        NSColor.black.setFill()
        NSColor.black.setStroke()

        let shield = shieldPath()
        switch state {
        case .connected:
            shield.fill()
            context.setBlendMode(.clear)
            drawLock(open: false)
            context.setBlendMode(.normal)
            keyholePath().fill()
        case .connecting, .disconnected:
            shield.lineWidth = 1.5
            shield.stroke()
            drawLock(open: state == .disconnected)
            context.setBlendMode(.clear)
            keyholePath().fill()
        case .unknown:
            shield.lineWidth = 1.5
            shield.stroke()
        }

        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func opacity(for state: VPNConnectionState) -> CGFloat {
        switch state {
        case .connected, .connecting:
            1.0
        case .disconnected, .unknown:
            dimmedOpacity
        }
    }

    /// A classic shield in an 18x18 point space (origin bottom-left).
    private static func shieldPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.lineJoinStyle = .round
        path.move(to: NSPoint(x: 9, y: 16.9))
        path.curve(to: NSPoint(x: 15.1, y: 14.6), controlPoint1: NSPoint(x: 11.2, y: 15.6), controlPoint2: NSPoint(x: 13.3, y: 14.9))
        path.line(to: NSPoint(x: 15.1, y: 9.6))
        path.curve(to: NSPoint(x: 9, y: 1.1), controlPoint1: NSPoint(x: 15.1, y: 5.6), controlPoint2: NSPoint(x: 12.4, y: 2.6))
        path.curve(to: NSPoint(x: 2.9, y: 9.6), controlPoint1: NSPoint(x: 5.6, y: 2.6), controlPoint2: NSPoint(x: 2.9, y: 5.6))
        path.line(to: NSPoint(x: 2.9, y: 14.6))
        path.curve(to: NSPoint(x: 9, y: 16.9), controlPoint1: NSPoint(x: 4.7, y: 14.9), controlPoint2: NSPoint(x: 6.8, y: 15.6))
        path.close()
        return path
    }

    static let lockBody = NSRect(x: 6.1, y: 4.9, width: 5.8, height: 4.4)
    static let keyholeCenter = NSPoint(x: 9, y: 7.2)
    private static let shackleRadius: CGFloat = 1.75
    private static let shackleLineWidth: CGFloat = 1.3
    private static let openShackleLift: CGFloat = 1.5

    private static func drawLock(open: Bool) {
        NSBezierPath(roundedRect: lockBody, xRadius: 1.0, yRadius: 1.0).fill()

        // Shackle legs start inside the body so the joint is seamless; an open lock lifts it.
        let lift = open ? openShackleLift : 0
        let legBottom = lockBody.maxY - 0.6
        let legTop = lockBody.maxY + 1.0 + lift
        let center = NSPoint(x: lockBody.midX, y: legTop)
        let shackle = NSBezierPath()
        shackle.lineWidth = shackleLineWidth
        shackle.lineCapStyle = .butt
        shackle.move(to: NSPoint(x: center.x - shackleRadius, y: open ? legTop - 0.4 : legBottom))
        shackle.line(to: NSPoint(x: center.x - shackleRadius, y: legTop))
        shackle.appendArc(withCenter: center, radius: shackleRadius, startAngle: 180, endAngle: 0, clockwise: true)
        shackle.line(to: NSPoint(x: center.x + shackleRadius, y: legBottom))
        shackle.stroke()
    }

    private static func keyholePath() -> NSBezierPath {
        let radius: CGFloat = 0.75
        let path = NSBezierPath(ovalIn: NSRect(
            x: keyholeCenter.x - radius,
            y: keyholeCenter.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        path.append(NSBezierPath(rect: NSRect(x: keyholeCenter.x - 0.35, y: keyholeCenter.y - 1.5, width: 0.7, height: 1.4)))
        return path
    }
}
