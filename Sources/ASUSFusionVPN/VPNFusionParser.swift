import Foundation

struct VPNFusionProfile: Equatable, Sendable {
    let name: String
    let unit: Int
    let isEnabled: Bool
    let rawRow: String
}

enum VPNFusionParser {
    static func status(from output: String, profileName: String, unit: Int) -> VPNStatus {
        let cleanedOutput = output
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("spawn ") }
            .joined(separator: "\n")
        let values = parseKeyValues(cleanedOutput)
        let clientList = values["vpnc_clientlist"] ?? ""
        let activeFlag = activeFlag(in: clientList, unit: unit)
        let stateCode = values["vpnc_state"] ?? ""
        let interfaceRunning = values["interface_running"] == "1"
        let policyRuleCount = Int(values["policy_rule_count"] ?? "") ?? 0
        let vpnRouteCount = Int(values["vpn_route_count"] ?? "") ?? 0
        let routerEpoch = Int(values["router_epoch"] ?? "") ?? 0
        let vpnLatestHandshake = Int(values["vpn_latest_handshake"] ?? "") ?? 0
        let runtimeVPNActive = interfaceRunning || vpnRouteCount > 0
        let freshHandshake = hasFreshHandshake(
            latestHandshake: vpnLatestHandshake,
            routerEpoch: routerEpoch
        )
        let wanInfo = ipInfoBlock(named: "WAN_IPINFO", in: cleanedOutput)
        let vpnInfo = ipInfoBlock(named: "VPN_IPINFO", in: cleanedOutput)
        let vpnEndpointHost = values["vpn_endpoint_host"]

        let state: VPNConnectionState
        if activeFlag && stateCode == "2" && runtimeVPNActive && freshHandshake {
            state = .connected
        } else if !activeFlag && runtimeVPNActive {
            state = .connected
        } else if activeFlag && stateCode != "0" {
            state = .connecting
        } else if !activeFlag {
            state = .disconnected
        } else {
            state = .unknown
        }

        return VPNStatus(
            state: state,
            profileName: profileName,
            unit: unit,
            activeFlag: activeFlag,
            stateCode: stateCode,
            interfaceRunning: interfaceRunning,
            rawClientList: clientList,
            wanIP: firstNonEmpty(values["wan_ip"], wanInfo?.ip),
            wanLocation: wanInfo?.displayLocation,
            vpnTunnelIP: values["vpn_tunnel_ip"],
            vpnEndpointHost: vpnEndpointHost,
            vpnEndpointIP: firstNonEmpty(values["vpn_endpoint_ip"], vpnInfo?.ip),
            vpnLocation: firstNonEmpty(vpnInfo?.displayLocation, locationFromEndpointHost(vpnEndpointHost)),
            policyRuleCount: policyRuleCount,
            vpnRouteCount: vpnRouteCount,
            routerCPUPercent: Int(values["router_cpu_percent"] ?? ""),
            routerMemoryUsedMB: Int(values["router_memory_used_mb"] ?? ""),
            routerMemoryTotalMB: Int(values["router_memory_total_mb"] ?? ""),
            routerMemoryPercent: Int(values["router_memory_percent"] ?? "")
        )
    }

    static func updatedClientList(_ clientList: String, unit: Int, enabled: Bool) throws -> String {
        let rows = profileRows(clientList)
        var updatedRows: [String] = []
        var didUpdate = false

        for row in rows {
            var fields = row.split(separator: ">", omittingEmptySubsequences: false).map(String.init)
            if profileUnit(row) == unit {
                while fields.count <= 5 {
                    fields.append("")
                }
                fields[5] = enabled ? "1" : "0"
                didUpdate = true
            }
            updatedRows.append(fields.joined(separator: ">"))
        }

        guard didUpdate else {
            throw SSHError(message: "Could not find VPN Fusion unit \(unit) in vpnc_clientlist.")
        }

        return updatedRows.joined(separator: "<")
    }

    static func profiles(fromClientList clientList: String) -> [VPNFusionProfile] {
        profileRows(clientList).compactMap { row in
            let fields = row.split(separator: ">", omittingEmptySubsequences: false).map(String.init)
            guard let unit = profileUnit(row) else {
                return nil
            }

            let name = firstNonEmpty(
                fields[safe: 0],
                fields[safe: 1],
                "Unit \(unit)"
            ) ?? "Unit \(unit)"

            return VPNFusionProfile(
                name: name,
                unit: unit,
                isEnabled: (fields[safe: 5] ?? "") == "1",
                rawRow: row
            )
        }
    }

    private static func parseKeyValues(_ output: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in output.components(separatedBy: .newlines) {
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value
        }
        return values
    }

    private static func ipInfoBlock(named name: String, in output: String) -> IPInfo? {
        let begin = "\(name)_BEGIN"
        let end = "\(name)_END"
        guard
            let beginRange = output.range(of: begin),
            let endRange = output.range(of: end, range: beginRange.upperBound..<output.endIndex)
        else {
            return nil
        }

        let json = String(output[beginRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !json.isEmpty, let data = json.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(IPInfo.self, from: data)
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedValue.isEmpty {
                return trimmedValue
            }
        }

        return nil
    }

    private static func hasFreshHandshake(latestHandshake: Int, routerEpoch: Int) -> Bool {
        guard latestHandshake > 0 else { return false }
        guard routerEpoch > 0 else { return true }

        let age = max(0, routerEpoch - latestHandshake)
        return age <= 180
    }

    private static func locationFromEndpointHost(_ host: String?) -> String? {
        guard let host else { return nil }
        let lowercasedHost = host.lowercased()
        let knownLocations = [
            "us-nyc": "New York, US",
            "us-lax": "Los Angeles, US",
            "us-mia": "Miami, US",
            "us-chi": "Chicago, US",
            "us-dal": "Dallas, US",
            "us-sea": "Seattle, US",
            "uk-lon": "London, GB",
            "de-fra": "Frankfurt, DE",
            "nl-ams": "Amsterdam, NL",
            "fr-par": "Paris, FR"
        ]

        return knownLocations.first { lowercasedHost.contains($0.key) }?.value
    }

    private static func activeFlag(in clientList: String, unit: Int) -> Bool {
        guard let row = profileRows(clientList).first(where: { profileUnit($0) == unit }) else {
            return false
        }

        let fields = row.split(separator: ">", omittingEmptySubsequences: false).map(String.init)
        guard fields.count > 5 else { return false }
        return fields[5] == "1"
    }

    private static func profileRows(_ clientList: String) -> [String] {
        clientList
            .split(separator: "<", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private static func profileUnit(_ row: String) -> Int? {
        let fields = row.split(separator: ">", omittingEmptySubsequences: false).map(String.init)
        if fields.count > 6, let value = Int(fields[6]) {
            return value
        }
        if fields.count > 2, let value = Int(fields[2]) {
            return value
        }
        return nil
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct IPInfo: Decodable {
    let ip: String?
    let city: String?
    let region: String?
    let country: String?

    var displayLocation: String? {
        let location = [city, region, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        return location.isEmpty ? nil : location
    }
}
