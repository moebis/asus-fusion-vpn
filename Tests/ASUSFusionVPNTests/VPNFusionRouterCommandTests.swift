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
    #expect(commands.contains { $0.contains("service start_wgc") })
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
    let wireGuardIndex = try #require(commands.firstIndex { $0.contains("service start_wgc") })
    let policyIndex = try #require(commands.firstIndex { $0.contains("sleep 4") && $0.contains("ip rule add") })
    #expect(serviceIndex < policyIndex)
    #expect(wireGuardIndex < policyIndex)
}

@Test func statusCommandUsesConfiguredRouteTable() {
    let command = SSHRouterClient.statusCommand(unit: 7, includeResourceUsage: true)

    #expect(command.contains("lookup 7"))
    #expect(command.contains("table 7"))
    #expect(!command.contains("lookup 5"))
    #expect(!command.contains("table 5"))
}

@Test func statusCommandDoesNotCallExternalServicesOrSleepOnRouter() {
    let command = SSHRouterClient.statusCommand(unit: 5, includeResourceUsage: true)

    #expect(!command.contains("curl"))
    #expect(!command.contains("ip2location.io"))
    #expect(!command.contains("ipinfo.io"))
    #expect(!command.contains("sleep"))
    #expect(!command.contains("/tmp/"))
}

@Test func geolocationURLsPreferIP2LocationOverHTTPS() throws {
    let urls = IPLocationResolver.geolocationURLs(for: "203.0.113.10").map(\.absoluteString)

    #expect(urls == [
        "https://api.ip2location.io/?ip=203.0.113.10",
        "https://ipinfo.io/203.0.113.10/json"
    ])
}

@Test func geolocationOnlyAcceptsIPv4Addresses() {
    #expect(IPLocationResolver.normalizedIPAddress(" 203.0.113.10\n") == "203.0.113.10")
    #expect(IPLocationResolver.normalizedIPAddress("") == nil)
    #expect(IPLocationResolver.normalizedIPAddress(nil) == nil)
    #expect(IPLocationResolver.normalizedIPAddress("203.0.113.10/json?x") == nil)
}

@Test func statusCommandCollectsRawRouterResourceCounters() {
    let command = SSHRouterClient.statusCommand(unit: 5, includeResourceUsage: true)

    #expect(command.contains("/proc/stat"))
    #expect(command.contains("/proc/meminfo"))
    #expect(command.contains("router_cpu_idle="))
    #expect(command.contains("router_cpu_total="))
    #expect(command.contains("router_memory_percent="))
}

@Test func statusCommandCanSkipRouterResourceUsageForFastPolling() {
    let command = SSHRouterClient.statusCommand(unit: 5, includeResourceUsage: false)

    #expect(!command.contains("/proc/stat"))
    #expect(!command.contains("/proc/meminfo"))
    #expect(command.contains("vpnc_clientlist"))
    #expect(command.contains("vpn_route_count"))
}

@Test func sshArgumentsQuotePathsAndEnableMultiplexing() {
    let arguments = SSHRouterClient.sshArguments(
        port: 2222,
        target: "admin@192.168.1.1",
        knownHostsPath: "/Users/me/Library/Application Support/ASUS Fusion VPN/known_hosts",
        controlPath: "/tmp/afv-abc.sock",
        command: "true"
    )

    #expect(arguments.contains("UserKnownHostsFile=\"/Users/me/Library/Application Support/ASUS Fusion VPN/known_hosts\""))
    #expect(arguments.contains("ControlMaster=auto"))
    #expect(arguments.contains("ControlPath=\"/tmp/afv-abc.sock\""))
    #expect(arguments.contains("NumberOfPasswordPrompts=1"))
    #expect(Array(arguments.suffix(3)) == ["--", "admin@192.168.1.1", "true"])
}

@Test func sshArgumentsCanDisableMultiplexing() {
    let arguments = SSHRouterClient.sshArguments(
        port: 22,
        target: "admin@192.168.1.1",
        knownHostsPath: "/tmp/known_hosts",
        controlPath: nil,
        command: "true"
    )

    #expect(arguments.contains("ControlMaster=no"))
    #expect(arguments.contains("ControlPath=none"))
    #expect(!arguments.contains { $0.hasPrefix("ControlPersist") })
}

@Test func multiplexingFailuresAreRecognized() {
    #expect(SSHRouterClient.isMultiplexingFailure("mux_client_request_session: session request failed: Session open refused by peer"))
    #expect(SSHRouterClient.isMultiplexingFailure("ControlSocket /tmp/x already exists, disabling multiplexing"))
    #expect(!SSHRouterClient.isMultiplexingFailure("admin@192.168.1.1: Permission denied (password)."))
}
