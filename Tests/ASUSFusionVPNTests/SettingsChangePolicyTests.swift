import Testing
@testable import ASUSFusionVPN

@Test func changingRegionWhileConnectedRequiresReconnect() {
    let oldSettings = testSettings(endpoint: "us-kan.prod.surfshark.com")
    let newSettings = testSettings(endpoint: "us-nyc.prod.surfshark.com")

    let action = SettingsChangePolicy.action(
        oldSettings: oldSettings,
        newSettings: newSettings,
        currentState: .connected
    )

    #expect(action == .reconnect)
}

@Test func changingRegionWhileDisconnectedOnlyRefreshes() {
    let oldSettings = testSettings(endpoint: "us-kan.prod.surfshark.com")
    let newSettings = testSettings(endpoint: "us-nyc.prod.surfshark.com")

    let action = SettingsChangePolicy.action(
        oldSettings: oldSettings,
        newSettings: newSettings,
        currentState: .disconnected
    )

    #expect(action == .refresh)
}

@Test func savingSameRegionReconnectsWhenLiveEndpointIsDifferent() {
    let oldSettings = testSettings(endpoint: "us-nyc.prod.surfshark.com")
    let newSettings = testSettings(endpoint: "us-nyc.prod.surfshark.com")

    let action = SettingsChangePolicy.action(
        oldSettings: oldSettings,
        newSettings: newSettings,
        currentState: .connected,
        currentEndpointHost: "us-kan.prod.surfshark.com"
    )

    #expect(action == .reconnect)
}

@Test func savingSameRegionWhileConnectedOnlyRefreshes() {
    let oldSettings = testSettings(endpoint: "us-kan.prod.surfshark.com")
    let newSettings = testSettings(endpoint: "us-kan.prod.surfshark.com")

    let action = SettingsChangePolicy.action(
        oldSettings: oldSettings,
        newSettings: newSettings,
        currentState: .connected
    )

    #expect(action == .refresh)
}

private func testSettings(endpoint: String) -> AppSettings {
    AppSettings(
        routerHost: "192.168.1.1",
        sshPort: 22,
        username: "admin",
        password: "test",
        profileName: "Surfshark",
        vpnUnit: 5,
        selectedRegionEndpoint: endpoint,
        selectedRegionPublicKey: "public-key-\(endpoint)",
        favoriteRegionEndpoints: []
    )
}
