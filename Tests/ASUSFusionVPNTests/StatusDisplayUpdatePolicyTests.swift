import Testing
@testable import ASUSFusionVPN

@Test func stateChromeDoesNotUpdateWhenStateAndProfileAreUnchanged() {
    #expect(!StatusDisplayUpdatePolicy.shouldUpdateStateChrome(
        previousDisplayState: .disconnected,
        nextDisplayState: .disconnected,
        previousProfileName: "Surfshark",
        nextProfileName: "Surfshark"
    ))
}

@Test func stateChromeUpdatesWhenDisplayStateChanges() {
    #expect(StatusDisplayUpdatePolicy.shouldUpdateStateChrome(
        previousDisplayState: .disconnected,
        nextDisplayState: .connected,
        previousProfileName: "Surfshark",
        nextProfileName: "Surfshark"
    ))
}

@Test func stateChromeUpdatesWhenProfileNameChanges() {
    #expect(StatusDisplayUpdatePolicy.shouldUpdateStateChrome(
        previousDisplayState: .connected,
        nextDisplayState: .connected,
        previousProfileName: "Surfshark",
        nextProfileName: "NordVPN"
    ))
}

@Test func statusDetailsUpdateOnlyWhenStatusChanges() {
    let status = testStatus(state: .connected, routerCPUPercent: 4)
    let sameStatus = testStatus(state: .connected, routerCPUPercent: 4)
    let changedStatus = testStatus(state: .connected, routerCPUPercent: 5)

    #expect(!StatusDisplayUpdatePolicy.shouldUpdateStatusDetails(previousStatus: status, nextStatus: sameStatus))
    #expect(StatusDisplayUpdatePolicy.shouldUpdateStatusDetails(previousStatus: status, nextStatus: changedStatus))
}

private func testStatus(
    state: VPNConnectionState,
    routerCPUPercent: Int?
) -> VPNStatus {
    VPNStatus(
        state: state,
        profileName: "Surfshark",
        unit: 5,
        activeFlag: state != .disconnected,
        stateCode: state == .disconnected ? "0" : "2",
        interfaceRunning: state == .connected,
        rawClientList: "Surfshark>Surfshark>5>>>1>5>>>0>0>Web",
        wanIP: "203.0.113.10",
        wanLocation: "Example City, ZZ",
        vpnTunnelIP: state == .connected ? "10.0.0.2" : nil,
        vpnEndpointHost: "us-nyc.prod.surfshark.com",
        vpnEndpointIP: state == .connected ? "198.51.100.25" : nil,
        vpnLocation: state == .connected ? "New York, US" : nil,
        policyRuleCount: state == .connected ? 2 : 0,
        vpnRouteCount: state == .connected ? 2 : 0,
        routerCPUPercent: routerCPUPercent,
        routerMemoryUsedMB: 300,
        routerMemoryTotalMB: 512,
        routerMemoryPercent: 59
    )
}
