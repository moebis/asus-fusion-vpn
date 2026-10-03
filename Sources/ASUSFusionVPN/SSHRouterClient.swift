import CryptoKit
import Foundation
import os

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
    var state: VPNConnectionState
    var profileName: String
    var unit: Int
    var activeFlag: Bool
    var stateCode: String
    var interfaceRunning: Bool
    var rawClientList: String
    var wanIP: String?
    var wanLocation: String?
    var vpnTunnelIP: String?
    var vpnEndpointHost: String?
    var vpnEndpointIP: String?
    var vpnLocation: String?
    var policyRuleCount: Int
    var vpnRouteCount: Int
    var routerCPUSample: RouterCPUSample?
    var routerCPUPercent: Int?
    var routerMemoryUsedMB: Int?
    var routerMemoryTotalMB: Int?
    var routerMemoryPercent: Int?
}

/// Cumulative jiffy counters from the router's `/proc/stat`. CPU usage is derived from the
/// difference between two polls, so status refreshes never have to sleep on the router.
struct RouterCPUSample: Equatable, Sendable {
    let idle: Int
    let total: Int

    func usagePercent(since previous: RouterCPUSample) -> Int? {
        let totalDelta = total - previous.total
        let idleDelta = idle - previous.idle
        guard totalDelta > 0, idleDelta >= 0, idleDelta <= totalDelta else {
            return nil
        }

        return Int((Double(totalDelta - idleDelta) * 100 / Double(totalDelta)).rounded())
    }
}

/// Talks to the router with the system OpenSSH client.
///
/// Connections are multiplexed: the first command authenticates and leaves a master
/// connection open for a short idle period, so the 30 second status poll reuses one
/// authenticated session instead of performing a full key exchange and password login
/// (and a router syslog entry) every time. The password is supplied through
/// `SSH_ASKPASS`, served by this app's own executable (see `AskPass`).
struct SSHRouterClient: Sendable {
    static let statusTimeout: TimeInterval = 20
    static let actionTimeout: TimeInterval = 60
    private static let controlPersistSeconds = 120
    private static let multiplexingDisabled = OSAllocatedUnfairLock(initialState: false)

    let settings: AppSettings

    func status(includeResourceUsage: Bool = true) async throws -> VPNStatus {
        let output = try await run(
            Self.statusCommand(unit: settings.vpnUnit, includeResourceUsage: includeResourceUsage),
            timeout: Self.statusTimeout
        )
        return VPNFusionParser.status(
            from: output,
            profileName: settings.profileName,
            unit: settings.vpnUnit
        )
    }

    func vpnFusionProfiles() async throws -> [VPNFusionProfile] {
        let output = try await run("nvram get vpnc_clientlist", timeout: Self.statusTimeout)
        return VPNFusionParser.profiles(fromClientList: output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func setEnabled(_ enabled: Bool) async throws -> VPNStatus {
        let clientList = try await run("nvram get vpnc_clientlist", timeout: Self.statusTimeout)
        let updatedClientList = try VPNFusionParser.updatedClientList(
            clientList.trimmingCharacters(in: .whitespacesAndNewlines),
            unit: settings.vpnUnit,
            enabled: enabled
        )
        let commands = VPNFusionRouterCommands.activationCommands(
            clientList: updatedClientList,
            unit: settings.vpnUnit,
            enabled: enabled,
            selectedRegion: enabled ? settings.selectedRegion : nil
        )

        _ = try await run(commands.joined(separator: "; "), timeout: Self.actionTimeout)
        return try await waitForExpectedState(enabled: enabled)
    }

    /// Closes the shared master connection, if one is open. Fire-and-forget so it is
    /// safe to call while the app is terminating.
    func closeSharedConnection() {
        guard let controlPath = controlPath() else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-O", "exit",
            "-o", "ControlPath=\(Self.quotedOptionValue(controlPath))",
            "-p", String(settings.sshPort),
            "--", settings.target
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    static func statusCommand(unit: Int, includeResourceUsage: Bool) -> String {
        let resourceUsageCommand = includeResourceUsage
            ? """
            awk '/^cpu / { idle=$5+$6; total=0; for (i=2; i<=NF; i++) total += $i; printf "router_cpu_idle=%.0f\\nrouter_cpu_total=%.0f\\n", idle, total; exit }' /proc/stat; \
            awk '/^MemTotal:/ { total=$2 } /^MemAvailable:/ { available=$2 } /^MemFree:/ { free=$2 } /^Buffers:/ { buffers=$2 } /^Cached:/ { cached=$2 } END { if (available == "") available = free + buffers + cached; if (total > 0) { used = total - available; if (used < 0) used = 0; used_mb = int((used + 512) / 1024); total_mb = int((total + 512) / 1024); percent = int(((used * 100) + (total / 2)) / total); printf "router_memory_used_mb=%d\\nrouter_memory_total_mb=%d\\nrouter_memory_percent=%d\\n", used_mb, total_mb, percent } }' /proc/meminfo
            """
            : "true"

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
        echo vpn_endpoint_ip=$(wg show wgc${unit} endpoints 2>/dev/null | awk '{ sub(/:[0-9]+$/, "", $2); print $2; exit }'); \
        if ifconfig wgc${unit} 2>/dev/null | grep -q RUNNING; then echo interface_running=1; else echo interface_running=0; fi; \
        \(resourceUsageCommand)
        """
    }

    static func sshArguments(
        port: Int,
        target: String,
        knownHostsPath: String,
        controlPath: String?,
        command: String
    ) -> [String] {
        var arguments = [
            "-T",
            "-p", String(port),
            "-o", "UserKnownHostsFile=\(quotedOptionValue(knownHostsPath))",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=8",
            "-o", "ServerAliveInterval=10",
            "-o", "ServerAliveCountMax=2",
            "-o", "NumberOfPasswordPrompts=1",
            "-o", "LogLevel=ERROR"
        ]
        if let controlPath {
            arguments += [
                "-o", "ControlMaster=auto",
                "-o", "ControlPath=\(quotedOptionValue(controlPath))",
                "-o", "ControlPersist=\(controlPersistSeconds)"
            ]
        } else {
            arguments += ["-o", "ControlMaster=no", "-o", "ControlPath=none"]
        }
        arguments += ["--", target, command]
        return arguments
    }

    /// OpenSSH splits `-o` values on whitespace, so paths such as
    /// `~/Library/Application Support/...` must be quoted.
    static func quotedOptionValue(_ value: String) -> String {
        "\"\(value)\""
    }

    static func isMultiplexingFailure(_ standardError: String) -> Bool {
        let markers = ["mux_client", "control socket", "controlsocket", "session open refused", "master refused session"]
        let lowercased = standardError.lowercased()
        return markers.contains { lowercased.contains($0) }
    }

    private func waitForExpectedState(enabled: Bool) async throws -> VPNStatus {
        let deadline = Date().addingTimeInterval(enabled ? 45 : 12)
        let pollInterval: Duration = enabled ? .seconds(2) : .seconds(1)
        var latestStatus = try await status(includeResourceUsage: false)

        while Date() < deadline {
            if latestStatus.state == (enabled ? .connected : .disconnected) {
                break
            }

            try await Task.sleep(for: pollInterval)
            latestStatus = try await status(includeResourceUsage: false)
        }

        // One full read so the menu shows router resources alongside the final state.
        return (try? await status()) ?? latestStatus
    }

    private func run(_ command: String, timeout: TimeInterval) async throws -> String {
        guard !settings.password.isEmpty else {
            throw SSHError(message: "Open Settings and enter the router username and password.")
        }
        guard let askPassPath = Bundle.main.executablePath else {
            throw SSHError(message: "Could not locate the app executable for SSH authentication.")
        }

        let knownHostsPath = try appKnownHostsPath()
        let useMultiplexing = !Self.multiplexingDisabled.withLock { $0 }
        let output = try await runSSH(
            command,
            controlPath: useMultiplexing ? controlPath() : nil,
            knownHostsPath: knownHostsPath,
            askPassPath: askPassPath,
            timeout: timeout
        )

        if output.status == 255, useMultiplexing, Self.isMultiplexingFailure(output.standardError) {
            // Some firmware refuses extra sessions on a shared connection. Fall back to
            // one connection per command for the rest of this run.
            Self.multiplexingDisabled.withLock { $0 = true }
            closeSharedConnection()
            return try await run(command, timeout: timeout)
        }

        guard output.status == 0 else {
            throw SSHError(sshFailure: output)
        }
        return output.standardOutput
    }

    private func runSSH(
        _ command: String,
        controlPath: String?,
        knownHostsPath: String,
        askPassPath: String,
        timeout: TimeInterval
    ) async throws -> ProcessOutput {
        try await ProcessRunner.run(
            executable: "/usr/bin/ssh",
            arguments: Self.sshArguments(
                port: settings.sshPort,
                target: settings.target,
                knownHostsPath: knownHostsPath,
                controlPath: controlPath,
                command: command
            ),
            environment: [
                "SSH_ASKPASS": askPassPath,
                "SSH_ASKPASS_REQUIRE": "force",
                AskPass.modeEnvironmentKey: "1",
                AskPass.passwordEnvironmentKey: settings.password
            ],
            timeout: timeout
        )
    }

    /// A short, per-user socket path. Unix socket paths are limited to 104 bytes and
    /// OpenSSH appends a temporary suffix while creating the master.
    private func controlPath() -> String? {
        let identity = "\(settings.username)@\(settings.routerHost):\(settings.sshPort)"
        let digest = SHA256.hash(data: Data(identity.utf8))
            .prefix(6)
            .map { String(format: "%02x", $0) }
            .joined()
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("afv-\(digest).sock")
        guard path.utf8.count <= 80, !path.contains("%"), !path.contains("\"") else {
            return nil
        }
        return path
    }

    private func appKnownHostsPath() throws -> String {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directoryURL = baseURL.appendingPathComponent("ASUS Fusion VPN", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("known_hosts").path
    }
}

struct SSHError: LocalizedError, Sendable {
    let message: String

    init(message: String) {
        self.message = message
    }

    init(sshFailure output: ProcessOutput) {
        let detail = output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if detail.localizedCaseInsensitiveContains("permission denied") {
            message = "The router rejected the SSH username or password."
        } else if detail.isEmpty {
            message = "SSH command failed with exit status \(output.status)."
        } else {
            message = detail
        }
    }

    var errorDescription: String? {
        message.isEmpty ? "SSH command failed." : message
    }
}
