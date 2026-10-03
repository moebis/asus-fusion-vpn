import Foundation

/// Sample data for README and website screenshots.
///
/// Launch with `ASUS_FUSION_VPN_SCREENSHOT_DEMO=menu` (opens the status menu) or
/// `=settings` (opens the Settings window). Demo mode never talks to a router, never
/// polls, and never saves settings. Addresses come from the reserved documentation
/// ranges (RFC 5737), so screenshots need no redaction.
enum ScreenshotDemo {
    static let environmentKey = "ASUS_FUSION_VPN_SCREENSHOT_DEMO"

    enum Scene: String {
        case menu
        case settings
    }

    static let scene: Scene? = ProcessInfo.processInfo.environment[environmentKey].flatMap(Scene.init(rawValue:))

    static var isEnabled: Bool {
        scene != nil
    }

    static let settings = AppSettings(
        routerHost: "192.168.50.1",
        sshPort: 22,
        username: "admin",
        password: "screenshot-demo",
        profileName: "Surfshark",
        vpnUnit: 5,
        selectedRegionEndpoint: VPNRegionCatalog.fallbackRegion.endpointHost,
        selectedRegionPublicKey: VPNRegionCatalog.fallbackRegion.publicKey,
        favoriteRegionEndpoints: [VPNRegionCatalog.fallbackRegion.endpointHost],
        showIPLocations: true
    )

    static let status = VPNStatus(
        state: .connected,
        profileName: "Surfshark",
        unit: 5,
        activeFlag: true,
        stateCode: "2",
        interfaceRunning: true,
        rawClientList: "Surfshark>Surfshark>5>>>1>5>>>0>0>Web",
        wanIP: "203.0.113.24",
        wanLocation: "Portland, Oregon, United States",
        vpnTunnelIP: "10.14.0.2",
        vpnEndpointHost: VPNRegionCatalog.fallbackRegion.endpointHost,
        vpnEndpointIP: "198.51.100.37",
        vpnLocation: "New York City, New York, United States",
        policyRuleCount: 2,
        vpnRouteCount: 2,
        routerCPUSample: nil,
        routerCPUPercent: 6,
        routerMemoryUsedMB: 418,
        routerMemoryTotalMB: 1024,
        routerMemoryPercent: 41
    )
}
