import Darwin
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

struct VPNStatus: Equatable, Sendable {
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
    let routerCPUPercent: Int?
    let routerMemoryUsedMB: Int?
    let routerMemoryTotalMB: Int?
    let routerMemoryPercent: Int?

    func withWANLocation(_ wanLocation: String) -> VPNStatus {
        VPNStatus(
            state: state,
            profileName: profileName,
            unit: unit,
            activeFlag: activeFlag,
            stateCode: stateCode,
            interfaceRunning: interfaceRunning,
            rawClientList: rawClientList,
            wanIP: wanIP,
            wanLocation: wanLocation,
            vpnTunnelIP: vpnTunnelIP,
            vpnEndpointHost: vpnEndpointHost,
            vpnEndpointIP: vpnEndpointIP,
            vpnLocation: vpnLocation,
            policyRuleCount: policyRuleCount,
            vpnRouteCount: vpnRouteCount,
            routerCPUPercent: routerCPUPercent,
            routerMemoryUsedMB: routerMemoryUsedMB,
            routerMemoryTotalMB: routerMemoryTotalMB,
            routerMemoryPercent: routerMemoryPercent
        )
    }
}

struct SSHRouterClient: Sendable {
    private static let defaultProcessTimeout: TimeInterval = 45
    private static let terminationGracePeriod: TimeInterval = 2

    let settings: AppSettings

    func status(includeIPLocations: Bool? = nil, includeResourceUsage: Bool = true) throws -> VPNStatus {
        let shouldIncludeIPLocations = includeIPLocations ?? settings.showIPLocations
        let output = try runSSH(
            command: Self.statusCommand(
                unit: settings.vpnUnit,
                includeIPLocations: shouldIncludeIPLocations,
                includeResourceUsage: includeResourceUsage
            )
        )
        let status = VPNFusionParser.status(
            from: output,
            profileName: settings.profileName,
            unit: settings.vpnUnit
        )
        if shouldIncludeIPLocations,
           status.wanLocation == nil,
           let wanIP = status.wanIP,
           let location = Self.lookupLocation(for: wanIP) {
            return status.withWANLocation(location)
        }

        return status
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

    static func statusCommand(unit: Int, includeIPLocations: Bool, includeResourceUsage: Bool) -> String {
        let resourceUsageCommand: String
        if includeResourceUsage {
            resourceUsageCommand = """
            read_cpu_totals() { awk '/^cpu / { idle=$5+$6; total=0; for (i=2; i<=NF; i++) total += $i; printf "%d %d\\n", idle, total; exit }' /proc/stat; }; \
            set -- $(read_cpu_totals); cpu_idle_1=${1:-0}; cpu_total_1=${2:-0}; \
            sleep 1; \
            set -- $(read_cpu_totals); cpu_idle_2=${1:-0}; cpu_total_2=${2:-0}; \
            cpu_total_delta=$((cpu_total_2 - cpu_total_1)); \
            cpu_idle_delta=$((cpu_idle_2 - cpu_idle_1)); \
            if [ "$cpu_total_delta" -gt 0 ]; then echo router_cpu_percent=$(( (100 * (cpu_total_delta - cpu_idle_delta) + cpu_total_delta / 2) / cpu_total_delta )); else echo router_cpu_percent=0; fi; \
            awk '/^MemTotal:/ { total=$2 } /^MemAvailable:/ { available=$2 } /^MemFree:/ { free=$2 } /^Buffers:/ { buffers=$2 } /^Cached:/ { cached=$2 } END { if (available == "") available = free + buffers + cached; if (total > 0) { used = total - available; if (used < 0) used = 0; used_mb = int((used + 512) / 1024); total_mb = int((total + 512) / 1024); percent = int(((used * 100) + (total / 2)) / total); printf "router_memory_used_mb=%d\\nrouter_memory_total_mb=%d\\nrouter_memory_percent=%d\\n", used_mb, total_mb, percent } }' /proc/meminfo;
            """
        } else {
            resourceUsageCommand = ""
        }

        let ipInfoCommand: String
        if includeIPLocations {
            ipInfoCommand = """
            lookup_ip_info() { \
            lookup_ip="$1"; \
            case "$lookup_ip" in ""|*[!0-9.]* ) return;; esac; \
            lookup_response=$(curl -fsS --max-time 8 "https://api.ip2location.io/?ip=${lookup_ip}" 2>/dev/null || curl -fsS --max-time 8 "http://api.ip2location.io/?ip=${lookup_ip}" 2>/dev/null || true); \
            if echo "$lookup_response" | grep -q '"country_name"'; then printf '%s\\n' "$lookup_response"; else curl -fsS --max-time 8 "https://ipinfo.io/${lookup_ip}/json" 2>/dev/null || curl -fsS --max-time 8 "http://ipinfo.io/${lookup_ip}/json" 2>/dev/null || true; fi; \
            }; \
            wan_lookup_ip=$(nvram get wan0_ipaddr); \
            echo WAN_IPINFO_BEGIN; \
            lookup_ip_info "$wan_lookup_ip"; \
            echo; \
            echo WAN_IPINFO_END; \
            vpn_endpoint_ip=$(wg show wgc${unit} 2>/dev/null | sed -n 's/^[[:space:]]*endpoint: \\([^:]*\\):.*/\\1/p' | head -1); \
            if [ -n "$vpn_endpoint_ip" ]; then echo VPN_IPINFO_BEGIN; lookup_ip_info "$vpn_endpoint_ip"; echo; echo VPN_IPINFO_END; fi;
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
        \(resourceUsageCommand)
        \(ipInfoCommand)
        rm -f /tmp/asus_fusion_vpn_if
        """
    }

    static func geolocationURLs(for ipAddress: String) -> [URL] {
        [
            "https://api.ip2location.io/?ip=\(ipAddress)",
            "http://api.ip2location.io/?ip=\(ipAddress)",
            "https://ipinfo.io/\(ipAddress)/json",
            "http://ipinfo.io/\(ipAddress)/json"
        ].compactMap(URL.init(string:))
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

    private static func lookupLocation(for ipAddress: String) -> String? {
        let trimmedIPAddress = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedIPAddress.range(of: #"^[0-9.]+$"#, options: .regularExpression) != nil else {
            return nil
        }

        for url in geolocationURLs(for: trimmedIPAddress) {
            guard
                let data = fetchData(from: url),
                let location = VPNFusionParser.displayLocation(fromIPInfoData: data)
            else {
                continue
            }

            return location
        }

        return nil
    }

    private static func fetchData(from url: URL, timeout: TimeInterval = 6) -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let semaphore = DispatchSemaphore(value: 0)
        let responseBox = HTTPResponseBox()
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard
                let httpResponse = response as? HTTPURLResponse,
                200..<300 ~= httpResponse.statusCode
            else {
                return
            }

            responseBox.data = data
        }
        task.resume()

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            task.cancel()
            return nil
        }

        return responseBox.data
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
          timeout { catch close; catch wait result; exit 124 }
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

    func runProcess(
        executable: String,
        arguments: [String],
        environment: [String: String],
        standardInput: String? = nil,
        processTimeout: TimeInterval = Self.defaultProcessTimeout
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
        let terminationSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        try process.run()
        if let standardInput, let data = standardInput.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
            try? inputPipe.fileHandleForWriting.close()
        }

        if terminationSemaphore.wait(timeout: .now() + processTimeout) == .timedOut {
            process.terminate()
            if terminationSemaphore.wait(timeout: .now() + Self.terminationGracePeriod) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = terminationSemaphore.wait(timeout: .now() + Self.terminationGracePeriod)
            }

            let formattedTimeout = processTimeout == floor(processTimeout)
                ? "\(Int(processTimeout))"
                : String(format: "%.1f", processTimeout)
            throw SSHError(message: "SSH command timed out after \(formattedTimeout) seconds.")
        }

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

private final class HTTPResponseBox: @unchecked Sendable {
    var data: Data?
}

struct SSHError: LocalizedError, Sendable {
    let message: String

    var errorDescription: String? {
        message.isEmpty ? "SSH command failed." : message
    }
}
