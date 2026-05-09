enum SettingsChangePolicy {
    enum Action: Equatable {
        case refresh
        case reconnect
    }

    static func action(
        oldSettings: AppSettings,
        newSettings: AppSettings,
        currentState: VPNConnectionState?,
        currentEndpointHost: String? = nil
    ) -> Action {
        guard currentState == .connected else {
            return .refresh
        }

        if oldSettings.selectedRegionEndpoint.caseInsensitiveCompare(newSettings.selectedRegionEndpoint) != .orderedSame {
            return .reconnect
        }

        if
            let currentEndpointHost,
            currentEndpointHost.caseInsensitiveCompare(newSettings.selectedRegionEndpoint) != .orderedSame
        {
            return .reconnect
        }

        return .refresh
    }
}
