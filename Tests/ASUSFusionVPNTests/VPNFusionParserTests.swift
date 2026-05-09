import Testing
@testable import ASUSFusionVPN

@Test func connectedRouterOutputParsesAsConnected() throws {
    let output = """
    vpnc_clientlist=Surfshark>Surfshark>5>>>1>5>>>0>0>Web
    wgc_enable=1
    vpnc_state=2
    interface_running=1
    vpn_route_count=2
    router_epoch=200
    vpn_latest_handshake=180
    """

    let status = VPNFusionParser.status(
        from: output,
        profileName: "Surfshark",
        unit: 5
    )

    #expect(status.state == .connected)
    #expect(status.activeFlag)
    #expect(status.stateCode == "2")
    #expect(status.interfaceRunning)
}

@Test func connectedRouterOutputParsesWithTerminalCRLFLines() throws {
    let output = "vpnc_clientlist=Surfshark>Surfshark>5>>>1>5>>>0>0>Web\r\nwgc_enable=1\r\nvpnc_state=2\r\ninterface_running=1\r\nvpn_route_count=2\r\nrouter_epoch=200\r\nvpn_latest_handshake=180\r\n"

    let status = VPNFusionParser.status(
        from: output,
        profileName: "Surfshark",
        unit: 5
    )

    #expect(status.state == .connected)
    #expect(status.activeFlag)
}

@Test func clientListActivationFlagCanBeToggled() throws {
    let clientList = "Surfshark>Surfshark>5>>>1>5>>>0>0>Web"

    let disabled = try VPNFusionParser.updatedClientList(clientList, unit: 5, enabled: false)
    #expect(disabled == "Surfshark>Surfshark>5>>>0>5>>>0>0>Web")

    let enabled = try VPNFusionParser.updatedClientList(disabled, unit: 5, enabled: true)
    #expect(enabled == clientList)
}

@Test func clientListProfilesExposeNamesUnitsAndEnabledState() throws {
    let clientList = "NordVPN>NordVPN>2>>>0>2>>>0>0>Web<Surfshark>Surfshark>5>>>1>5>>>0>0>Web"

    let profiles = VPNFusionParser.profiles(fromClientList: clientList)

    #expect(profiles == [
        VPNFusionProfile(name: "NordVPN", unit: 2, isEnabled: false, rawRow: "NordVPN>NordVPN>2>>>0>2>>>0>0>Web"),
        VPNFusionProfile(name: "Surfshark", unit: 5, isEnabled: true, rawRow: "Surfshark>Surfshark>5>>>1>5>>>0>0>Web")
    ])
}

@Test func clientListProfilesIgnoreRowsWithoutUnit() throws {
    let clientList = "Broken>Broken>>>>>>>Web<Surfshark>Surfshark>5>>>1>5>>>0>0>Web"

    let profiles = VPNFusionParser.profiles(fromClientList: clientList)

    #expect(profiles.map(\.unit) == [5])
}

@Test func routerOutputParsesWanAndVPNIdentity() throws {
    let output = """
    vpnc_clientlist=Surfshark>Surfshark>5>>>1>5>>>0>0>Web
    wgc_enable=1
    vpnc_state=2
    interface_running=1
    vpn_route_count=2
    router_epoch=200
    vpn_latest_handshake=180
    wan_ip=203.0.113.10
    vpn_tunnel_ip=10.0.0.2
    vpn_endpoint_host=us-nyc.prod.surfshark.com
    vpn_endpoint_ip=198.51.100.25
    WAN_IPINFO_BEGIN
    {"ip":"203.0.113.10","city":"Example City","region":"Example Region","country":"ZZ"}
    WAN_IPINFO_END
    VPN_IPINFO_BEGIN
    {"ip":"198.51.100.25","city":"New York City","region":"New York","country":"US"}
    VPN_IPINFO_END
    """

    let status = VPNFusionParser.status(
        from: output,
        profileName: "Surfshark",
        unit: 5
    )

    #expect(status.wanIP == "203.0.113.10")
    #expect(status.wanLocation == "Example City, Example Region, ZZ")
    #expect(status.vpnTunnelIP == "10.0.0.2")
    #expect(status.vpnEndpointIP == "198.51.100.25")
    #expect(status.vpnLocation == "New York City, New York, US")
}

@Test func routerOutputIgnoresExpectSpawnTranscriptWhenParsingIPInfoBlocks() throws {
    let output = """
    spawn ssh router echo WAN_IPINFO_BEGIN; curl https://ipinfo.io/json; echo WAN_IPINFO_END
    vpnc_clientlist=Surfshark>Surfshark>5>>>1>5>>>0>0>Web
    wgc_enable=1
    vpnc_state=2
    interface_running=1
    vpn_route_count=2
    router_epoch=200
    vpn_latest_handshake=180
    wan_ip=203.0.113.10
    WAN_IPINFO_BEGIN
    {"ip":"203.0.113.10","city":"Example City","region":"Example Region","country":"ZZ"}
    WAN_IPINFO_END
    """

    let status = VPNFusionParser.status(
        from: output,
        profileName: "Surfshark",
        unit: 5
    )

    #expect(status.wanLocation == "Example City, Example Region, ZZ")
}

@Test func staleRuntimeWireGuardRoutesStillCountAsConnected() throws {
    let output = """
    vpnc_clientlist=Surfshark>Surfshark>5>>>0>5>>>0>0>Web
    wgc_enable=0
    vpnc_state=2
    interface_running=1
    policy_rule_count=5
    vpn_route_count=2
    """

    let status = VPNFusionParser.status(
        from: output,
        profileName: "Surfshark",
        unit: 5
    )

    #expect(status.state == .connected)
}

@Test func enabledProfileWithoutWireGuardHandshakeIsConnecting() throws {
    let output = """
    vpnc_clientlist=Surfshark>Surfshark>5>>>1>5>>>0>0>Web
    wgc_enable=1
    vpnc_state=2
    interface_running=0
    policy_rule_count=0
    vpn_route_count=0
    router_epoch=200
    vpn_latest_handshake=0
    """

    let status = VPNFusionParser.status(
        from: output,
        profileName: "Surfshark",
        unit: 5
    )

    #expect(status.state == .connecting)
}

@Test func staleWireGuardHandshakeDoesNotCountAsConnected() throws {
    let output = """
    vpnc_clientlist=Surfshark>Surfshark>5>>>1>5>>>0>0>Web
    wgc_enable=1
    vpnc_state=2
    interface_running=1
    policy_rule_count=5
    vpn_route_count=2
    router_epoch=600
    vpn_latest_handshake=100
    """

    let status = VPNFusionParser.status(
        from: output,
        profileName: "Surfshark",
        unit: 5
    )

    #expect(status.state == .connecting)
}

@Test func policyRulesWithoutLiveTunnelDoNotCountAsConnected() throws {
    let output = """
    vpnc_clientlist=Surfshark>Surfshark>5>>>0>5>>>0>0>Web
    wgc_enable=0
    vpnc_state=0
    interface_running=0
    policy_rule_count=5
    vpn_route_count=0
    """

    let status = VPNFusionParser.status(
        from: output,
        profileName: "Surfshark",
        unit: 5
    )

    #expect(status.state == .disconnected)
}
