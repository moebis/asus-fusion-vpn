import Foundation

enum VPNConnectionState: String, Sendable {
    case connected
    case connecting
    case disconnected
    case unknown

    var displayName: String {
        switch self {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .disconnected: "Disconnected"
        case .unknown: "Unknown"
        }
    }
}

struct VPNStatus: Sendable {
    let state: VPNConnectionState
    let profileName: String
    let unit: Int
    let activeFlag: Bool
    let stateCode: String
    let interfaceRunning: Bool
    let rawClientList: String
    let wanIP: String?
    let wanLocation: String?
    let vpnTunnelIP: String?
    let vpnEndpointHost: String?
    let vpnEndpointIP: String?
    let vpnLocation: String?
    let policyRuleCount: Int
    let vpnRouteCount: Int
}

struct SSHRouterClient: Sendable {
    let settings: AppSettings

    func status() throws -> VPNStatus {
        let output = try runSSH(command: Self.statusCommand(unit: settings.vpnUnit, includeIPLocations: settings.showIPLocations))
        return VPNFusionParser.status(
            from: output,
            profileName: settings.profileName,
            unit: settings.vpnUnit
        )
    }

    func vpnFusionProfiles() throws -> [VPNFusionProfile] {
        let output = try runSSH(command: "nvram get vpnc_clientlist")
        return VPNFusionParser.profiles(fromClientList: output)
    }

    func setEnabled(_ enabled: Bool) throws -> VPNStatus {
        let current = try status()
        let updatedClientList = try VPNFusionParser.updatedClientList(
            current.rawClientList,
            unit: settings.vpnUnit,
            enabled: enabled
        )
        let commands = VPNFusionRouterCommands.activationCommands(
            clientList: updatedClientList,
            unit: settings.vpnUnit,
            enabled: enabled,
            selectedRegion: enabled ? settings.selectedRegion : nil
        )

        _ = try runSSH(command: commands.joined(separator: "; "))
        return try waitForExpectedState(enabled: enabled)
    }

    static func statusCommand(unit: Int, includeIPLocations: Bool) -> String {
        let ipInfoCommand: String
        if includeIPLocations {
            ipInfoCommand = """
            echo WAN_IPINFO_BEGIN; \
            curl -fsS --max-time 8 https://ipinfo.io/json 2>/dev/null || true; \
            echo; \
            echo WAN_IPINFO_END; \
            vpn_endpoint_ip=$(wg show wgc${unit} 2>/dev/null | sed -n 's/^[[:space:]]*endpoint: \\([^:]*\\):.*/\\1/p' | head -1); \
            if [ -n "$vpn_endpoint_ip" ]; then echo VPN_IPINFO_BEGIN; curl -fsS --max-time 8 https://ipinfo.io/${vpn_endpoint_ip}/json 2>/dev/null || true; echo; echo VPN_IPINFO_END; fi;
            """
        } else {
            ipInfoCommand = ""
        }

        return """
        unit=\(unit); \
        echo vpnc_clientlist=$(nvram get vpnc_clientlist); \
        echo vpnc_unit=$(nvram get vpnc_unit); \
        echo wgc_enable=$(nvram get wgc${unit}_enable); \
        echo vpnc_state=$(nvram get vpnc${unit}_state_t); \
        echo policy_rule_count=$(ip rule show | grep -c 'lookup \(unit)'); \
        echo vpn_route_count=$(ip route show table \(unit) 2>/dev/null | grep -Ec 'dev wgc|0\\.0\\.0\\.0/1|128\\.0\\.0\\.0/1'); \
        echo wan_ip=$(nvram get wan0_ipaddr); \
        echo vpn_tunnel_ip=$(nvram get wgc${unit}_addr | cut -d/ -f1); \
        echo vpn_endpoint_host=$(nvram get wgc${unit}_ep_addr); \
        echo vpn_endpoint_ip=$(wg show wgc${unit} 2>/dev/null | sed -n 's/^[[:space:]]*endpoint: \\([^:]*\\):.*/\\1/p' | head -1); \
        echo router_epoch=$(date +%s); \
        echo vpn_latest_handshake=$(wg show wgc${unit} latest-handshakes 2>/dev/null | awk '{print $2; exit}'); \
        if ifconfig wgc${unit} >/tmp/asus_fusion_vpn_if 2>/dev/null; then echo interface_exists=1; if grep -q RUNNING /tmp/asus_fusion_vpn_if; then echo interface_running=1; else echo interface_running=0; fi; else echo interface_exists=0; echo interface_running=0; fi; \
        \(ipInfoCommand)
        rm -f /tmp/asus_fusion_vpn_if
        """
    }

    private func waitForExpectedState(enabled: Bool) throws -> VPNStatus {
        let deadline = Date().addingTimeInterval(enabled ? 45 : 12)
        var latestStatus = try status()

        while Date() < deadline {
            if enabled, latestStatus.state == .connected {
                return latestStatus
            }

            if !enabled, latestStatus.state == .disconnected {
                return latestStatus
            }

            Thread.sleep(forTimeInterval: enabled ? 3.0 : 1.5)
            latestStatus = try status()
        }

        return latestStatus
    }

    private func runSSH(command: String) throws -> String {
        guard !settings.password.isEmpty else {
            throw SSHError(message: "Open Settings and enter the router username and password.")
        }

        return try runSSHWithExpect(command: command, password: settings.password)
    }

    private func runSSHWithExpect(command: String, password: String) throws -> String {
        let knownHostsPath = try appKnownHostsPath()
        let script = """
        set timeout 30
        if {[gets stdin router_password] < 0} { set router_password "" }
        set ssh_argv [list /usr/bin/ssh -p $env(ASUS_FUSION_VPN_SSH_PORT) -o UserKnownHostsFile=$env(ASUS_FUSION_VPN_KNOWN_HOSTS) -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 $env(ASUS_FUSION_VPN_TARGET) $env(ASUS_FUSION_VPN_COMMAND)]
        spawn {*}$ssh_argv
        expect {
          -re "(?i)are you sure.*yes/no.*" { send "yes\\r"; exp_continue }
          -re "(?i)password:" { send -- "$router_password\\r"; exp_continue }
          eof
        }
        catch wait result
        exit [lindex $result 3]
        """

        return try runProcess(
            executable: "/usr/bin/expect",
            arguments: ["-c", script],
            environment: [
                "ASUS_FUSION_VPN_SSH_PORT": String(settings.sshPort),
                "ASUS_FUSION_VPN_TARGET": settings.target,
                "ASUS_FUSION_VPN_COMMAND": command,
                "ASUS_FUSION_VPN_KNOWN_HOSTS": knownHostsPath
            ],
            standardInput: password + "\n"
        )
    }

    private func appKnownHostsPath() throws -> String {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directoryURL = baseURL.appendingPathComponent("ASUS Fusion VPN", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("known_hosts").path
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        environment: [String: String],
        standardInput: String? = nil
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        let inputPipe = Pipe()
        if standardInput != nil {
            process.standardInput = inputPipe
        }

        try process.run()
        if let standardInput, let data = standardInput.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
            try? inputPipe.fileHandleForWriting.close()
        }
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let combined = [output, error].joined(separator: "\n")

        guard process.terminationStatus == 0 else {
            throw SSHError(message: combined.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return combined
            .components(separatedBy: .newlines)
            .filter {
                !$0.localizedCaseInsensitiveContains("password:")
                    && !$0.hasPrefix("spawn ")
            }
            .joined(separator: "\n")
    }

}

struct SSHError: LocalizedError, Sendable {
    let message: String

    var errorDescription: String? {
        message.isEmpty ? "SSH command failed." : message
    }
}
