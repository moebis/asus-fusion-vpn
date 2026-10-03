import Foundation

enum StatusRefreshPolicy {
    static let regularRefreshInterval: TimeInterval = 30
    static let regularRefreshTolerance: TimeInterval = 5
    static let regularRefreshRunLoopMode: RunLoop.Mode = .common
    static let toggleFollowUpRefreshDelay: TimeInterval = 3
    static let wakeRefreshDelay: TimeInterval = 5
    static let menuOpenStalenessThreshold: TimeInterval = 10

    static func followUpRefreshDelay(after state: VPNConnectionState) -> TimeInterval? {
        state == .connecting ? toggleFollowUpRefreshDelay : nil
    }

    static func shouldRefreshOnMenuOpen(lastRefreshDate: Date?, now: Date = Date()) -> Bool {
        guard let lastRefreshDate else { return true }
        return now.timeIntervalSince(lastRefreshDate) >= menuOpenStalenessThreshold
    }

    /// Settings that change who or how the app authenticates to the router.
    static func connectionSettingsChanged(from oldSettings: AppSettings, to newSettings: AppSettings) -> Bool {
        oldSettings.routerHost != newSettings.routerHost
            || oldSettings.sshPort != newSettings.sshPort
            || oldSettings.username != newSettings.username
            || oldSettings.password != newSettings.password
    }
}
