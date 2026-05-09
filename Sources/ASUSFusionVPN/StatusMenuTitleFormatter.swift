import AppKit

@MainActor
enum StatusMenuTitleFormatter {
    static let profileColor = NSColor.labelColor
    static let connectedColor = NSColor.systemGreen
    static let disconnectedColor = NSColor.systemRed
    static let connectingColor = NSColor.systemOrange
    static let detailColor = NSColor.secondaryLabelColor

    static func title(
        profileName: String,
        state: VPNConnectionState,
        regionName: String,
        vpnTunnelIP: String?
    ) -> NSAttributedString {
        let title = NSMutableAttributedString()
        title.append(segment("\(profileName): ", color: profileColor))
        title.append(segment(state.displayName, color: stateColor(for: state)))
        title.append(segment(detailText(regionName: regionName, vpnTunnelIP: vpnTunnelIP), color: detailColor))
        return title
    }

    static func plainTitle(_ text: String) -> NSAttributedString {
        segment(text, color: detailColor)
    }

    private static func detailText(regionName: String, vpnTunnelIP: String?) -> String {
        let trimmedTunnelIP = vpnTunnelIP?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedTunnelIP.isEmpty {
            return " - (\(regionName))"
        }

        return " - (\(regionName) - \(trimmedTunnelIP))"
    }

    private static func stateColor(for state: VPNConnectionState) -> NSColor {
        switch state {
        case .connected:
            connectedColor
        case .disconnected:
            disconnectedColor
        case .connecting:
            connectingColor
        case .unknown:
            detailColor
        }
    }

    private static func segment(_ text: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: color
            ]
        )
    }
}
