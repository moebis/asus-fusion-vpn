import Foundation

struct AppSettings: Equatable, Sendable {
    var routerHost: String
    var sshPort: Int
    var username: String
    var password: String
    var profileName: String
    var vpnUnit: Int
    var selectedRegionEndpoint: String
    var selectedRegionPublicKey: String
    var favoriteRegionEndpoints: [String]

    static let defaultRouterHost = "192.168.1.1"
    static let defaultProfileName = "Surfshark"
    static let defaultVPNUnit = 5

    static func load() -> AppSettings {
        let defaults = UserDefaults.standard
        let routerHost = defaults.string(forKey: Keys.routerHost) ?? defaultRouterHost
        let sshPort = defaults.object(forKey: Keys.sshPort) as? Int ?? 22
        let username = defaults.string(forKey: Keys.username) ?? ""
        let password = defaults.string(forKey: Keys.password) ?? ""
        let profileName = defaults.string(forKey: Keys.profileName) ?? defaultProfileName
        let vpnUnit = defaults.object(forKey: Keys.vpnUnit) as? Int ?? defaultVPNUnit
        let selectedRegionEndpoint = defaults.string(forKey: Keys.selectedRegionEndpoint)
            ?? VPNRegionCatalog.fallbackRegion.endpointHost
        let selectedRegionPublicKey = defaults.string(forKey: Keys.selectedRegionPublicKey)
            ?? VPNRegionCatalog.fallbackRegion.publicKey
        let favoriteRegionEndpoints = defaults.stringArray(forKey: Keys.favoriteRegionEndpoints) ?? []

        return AppSettings(
            routerHost: routerHost,
            sshPort: sshPort,
            username: username,
            password: password,
            profileName: profileName,
            vpnUnit: vpnUnit,
            selectedRegionEndpoint: selectedRegionEndpoint,
            selectedRegionPublicKey: selectedRegionPublicKey,
            favoriteRegionEndpoints: favoriteRegionEndpoints
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(routerHost, forKey: Keys.routerHost)
        defaults.set(sshPort, forKey: Keys.sshPort)
        defaults.set(username, forKey: Keys.username)
        defaults.set(password, forKey: Keys.password)
        defaults.set(profileName, forKey: Keys.profileName)
        defaults.set(vpnUnit, forKey: Keys.vpnUnit)
        defaults.set(selectedRegionEndpoint, forKey: Keys.selectedRegionEndpoint)
        defaults.set(selectedRegionPublicKey, forKey: Keys.selectedRegionPublicKey)
        defaults.set(favoriteRegionEndpoints, forKey: Keys.favoriteRegionEndpoints)
    }

    var target: String {
        "\(username)@\(routerHost)"
    }

    var selectedRegion: VPNRegion? {
        let endpoint = selectedRegionEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let publicKey = selectedRegionPublicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty, !publicKey.isEmpty else { return nil }

        return VPNRegion(
            country: "Selected",
            countryCode: nil,
            group: nil,
            location: endpoint,
            endpointHost: endpoint,
            publicKey: publicKey
        )
    }

    enum Keys {
        static let routerHost = "routerHost"
        static let sshPort = "sshPort"
        static let username = "username"
        static let password = "password"
        static let profileName = "profileName"
        static let vpnUnit = "vpnUnit"
        static let selectedRegionEndpoint = "selectedRegionEndpoint"
        static let selectedRegionPublicKey = "selectedRegionPublicKey"
        static let favoriteRegionEndpoints = "favoriteRegionEndpoints"
    }
}
