import Testing
@testable import ASUSFusionVPN

@Test func connectCommandsUpdateSelectedRegionEndpointAndPublicKey() throws {
    let region = VPNRegion(
        country: "Germany",
        countryCode: "DE",
        group: "Europe",
        location: "Frankfurt",
        endpointHost: "de-fra.prod.surfshark.com",
        publicKey: "de-public-key"
    )

    let commands = VPNFusionRouterCommands.activationCommands(
        clientList: "Surfshark>Surfshark>5>>>0>5>>>0>0>Web",
        unit: 5,
        enabled: true,
        selectedRegion: region
    )

    #expect(commands.contains("nvram set wgc5_ep_addr='de-fra.prod.surfshark.com'"))
    #expect(commands.contains("nvram set wgc5_ppub='de-public-key'"))
    _ = try #require(commands.first { $0.contains("nslookup 'de-fra.prod.surfshark.com'") })
    #expect(commands.contains { $0.contains("nvram set wgc5_ep_addr_r=\"$resolved_ep\"") })
    #expect(!commands.contains("nvram set wgc5_ep_addr_r=''"))
    #expect(commands.contains { $0.contains("service restart_vpnc") })
    #expect(commands.contains { $0.contains("ip rule add") })
}

@Test func disconnectCommandsDoNotChangeRegionEndpoint() throws {
    let commands = VPNFusionRouterCommands.activationCommands(
        clientList: "Surfshark>Surfshark>5>>>1>5>>>0>0>Web",
        unit: 5,
        enabled: false,
        selectedRegion: VPNRegionCatalog.fallbackRegion
    )

    #expect(!commands.contains { $0.contains("wgc5_ep_addr") })
    #expect(!commands.contains { $0.contains("wgc5_ppub") })
    #expect(commands.contains { $0.contains("service stop_vpnc") })
    #expect(commands.contains { $0.contains("ip link delete wgc5") })
    #expect(commands.contains { $0.contains("ip route flush table 5") })
}

@Test func activationCommandsRunRouterServiceBeforePolicyWork() throws {
    let commands = VPNFusionRouterCommands.activationCommands(
        clientList: "Surfshark>Surfshark>5>>>0>5>>>0>0>Web",
        unit: 5,
        enabled: true,
        selectedRegion: VPNRegionCatalog.fallbackRegion
    )

    let serviceIndex = try #require(commands.firstIndex { $0.contains("service restart_vpnc") })
    let policyIndex = try #require(commands.firstIndex { $0.contains("sleep 4") && $0.contains("ip rule add") })
    #expect(serviceIndex < policyIndex)
}

@Test func statusCommandUsesConfiguredRouteTable() {
    let command = SSHRouterClient.statusCommand(unit: 7, includeIPLocations: true, includeResourceUsage: true)

    #expect(command.contains("lookup 7"))
    #expect(command.contains("table 7"))
    #expect(!command.contains("lookup 5"))
    #expect(!command.contains("table 5"))
}

@Test func statusCommandOmitsIPInfoWhenLocationDetailsAreDisabled() {
    let command = SSHRouterClient.statusCommand(unit: 5, includeIPLocations: false, includeResourceUsage: true)

    #expect(!command.contains("ipinfo.io"))
    #expect(!command.contains("WAN_IPINFO_BEGIN"))
    #expect(!command.contains("VPN_IPINFO_BEGIN"))
}

@Test func statusCommandCollectsRouterResourceUsage() {
    let command = SSHRouterClient.statusCommand(unit: 5, includeIPLocations: false, includeResourceUsage: true)

    #expect(command.contains("/proc/stat"))
    #expect(command.contains("/proc/meminfo"))
    #expect(command.contains("router_cpu_percent="))
    #expect(command.contains("router_memory_percent="))
}

@Test func statusCommandCanSkipRouterResourceUsageForFastPolling() {
    let command = SSHRouterClient.statusCommand(unit: 5, includeIPLocations: false, includeResourceUsage: false)

    #expect(!command.contains("/proc/stat"))
    #expect(!command.contains("/proc/meminfo"))
    #expect(!command.contains("sleep 1"))
    #expect(command.contains("vpnc_clientlist"))
    #expect(command.contains("vpn_route_count"))
}
