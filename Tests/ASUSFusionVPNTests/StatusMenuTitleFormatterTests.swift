import AppKit
import Testing
@testable import ASUSFusionVPN

@MainActor
@Test func connectedStatusTitleColorsEachSegment() throws {
    let status = testStatus(state: .connected, tunnelIP: "10.0.0.2")

    let title = StatusMenuTitleFormatter.title(
        profileName: "Surfshark",
        state: status.state,
        regionName: "United States / New York",
        vpnTunnelIP: status.vpnTunnelIP
    )

    #expect(title.string == "Surfshark: Connected - (United States / New York - 10.0.0.2)")
    let profileColor = try foregroundColor(in: title, matching: "Surfshark:")
    let stateColor = try foregroundColor(in: title, matching: "Connected")
    let detailColor = try foregroundColor(in: title, matching: " - (United States / New York - 10.0.0.2)")
    #expect(profileColor === StatusMenuTitleFormatter.profileColor)
    #expect(profileColor.isEqual(NSColor.labelColor))
    #expect(stateColor === StatusMenuTitleFormatter.connectedColor)
    #expect(detailColor === StatusMenuTitleFormatter.detailColor)
}

@MainActor
@Test func disconnectedStatusTitleUsesRedStateAndNoTunnelIP() throws {
    let status = testStatus(state: .disconnected, tunnelIP: nil)

    let title = StatusMenuTitleFormatter.title(
        profileName: "Surfshark",
        state: status.state,
        regionName: "United States / New York",
        vpnTunnelIP: status.vpnTunnelIP
    )

    #expect(title.string == "Surfshark: Disconnected - (United States / New York)")
    let stateColor = try foregroundColor(in: title, matching: "Disconnected")
    let detailColor = try foregroundColor(in: title, matching: " - (United States / New York)")
    #expect(stateColor === StatusMenuTitleFormatter.disconnectedColor)
    #expect(detailColor === StatusMenuTitleFormatter.detailColor)
}

@MainActor
private func foregroundColor(in title: NSAttributedString, matching text: String) throws -> NSColor {
    let range = (title.string as NSString).range(of: text)
    guard range.location != NSNotFound else {
        throw StatusTitleTestError(message: "Could not find \(text) in title.")
    }

    guard let color = title.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor else {
        throw StatusTitleTestError(message: "Could not find foreground color for \(text).")
    }

    return color
}

private struct StatusTitleTestError: Error {
    let message: String
}

private func testStatus(state: VPNConnectionState, tunnelIP: String?) -> VPNStatus {
    VPNStatus(
        state: state,
        profileName: "Surfshark",
        unit: 5,
        activeFlag: state != .disconnected,
        stateCode: state == .disconnected ? "0" : "2",
        interfaceRunning: state == .connected,
        rawClientList: "Surfshark>Surfshark>5>>>1>5>>>0>0>Web",
        wanIP: nil,
        wanLocation: nil,
        vpnTunnelIP: tunnelIP,
        vpnEndpointHost: nil,
        vpnEndpointIP: nil,
        vpnLocation: nil,
        policyRuleCount: 0,
        vpnRouteCount: state == .connected ? 2 : 0
    )
}
