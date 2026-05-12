enum VPNFusionRouterCommands {
    static func activationCommands(
        clientList: String,
        unit: Int,
        enabled: Bool,
        selectedRegion: VPNRegion?
    ) -> [String] {
        var commands = [
            "nvram set vpnc_clientlist=\(shellQuote(clientList))",
            "nvram set vpnc_unit=\(unit)"
        ]

        if enabled, let selectedRegion {
            commands.append("nvram set wgc\(unit)_ep_addr=\(shellQuote(selectedRegion.endpointHost))")
            commands.append("nvram set wgc\(unit)_ppub=\(shellQuote(selectedRegion.publicKey))")
            commands.append(resolveEndpointCommand(unit: unit, endpointHost: selectedRegion.endpointHost))
        }

        commands.append("nvram commit")
        commands.append("service \(enabled ? "restart_vpnc" : "stop_vpnc")")
        if enabled {
            commands.append("service start_wgc")
        }
        commands.append(enabled ? connectPolicyCommand(unit: unit) : disconnectCleanupCommand(unit: unit))

        return commands
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private static func connectPolicyCommand(unit: Int) -> String {
        """
        sleep 4; \
        nvram get vpnc_dev_policy_list | tr '<' '\\n' | awk -F'>' -v unit=\(unit) '$1=="1" && $4==unit && $2 ~ /^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$/ {print $2}' | while read policy_ip; do ip rule add pref 100 from "$policy_ip" table \(unit) 2>/dev/null || true; done; \
        pref=1016; for dns_ip in $(nvram get vpnc\(unit)_dns | tr ',' ' '); do ip rule add pref "$pref" to "$dns_ip" iif lo table \(unit) 2>/dev/null || true; pref=$((pref + 1)); done
        """
    }

    private static func resolveEndpointCommand(unit: Int, endpointHost: String) -> String {
        """
        resolved_ep=$(nslookup \(shellQuote(endpointHost)) 2>/dev/null | awk '/^Address [0-9]+:/ {print $3; exit} /^Address: / {print $2; exit}'); \
        [ -n "$resolved_ep" ] && nvram set wgc\(unit)_ep_addr_r="$resolved_ep"
        """
    }

    private static func disconnectCleanupCommand(unit: Int) -> String {
        """
        sleep 1; \
        ip rule show | awk '/lookup \(unit)/ {print $1}' | sed 's/://' | sort -rn | while read pref; do ip rule del pref "$pref" 2>/dev/null || true; done; \
        ip route flush table \(unit) 2>/dev/null || true; \
        ip link set wgc\(unit) down 2>/dev/null || true; \
        ip link delete wgc\(unit) 2>/dev/null || true
        """
    }

}
