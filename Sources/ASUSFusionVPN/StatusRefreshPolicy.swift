import Foundation

enum StatusRefreshPolicy {
    static let regularRefreshInterval: TimeInterval = 30
    static let regularRefreshRunLoopMode: RunLoop.Mode = .common
    static let toggleFollowUpRefreshDelay: TimeInterval = 3

    static func followUpRefreshDelay(after state: VPNConnectionState) -> TimeInterval? {
        state == .connecting ? toggleFollowUpRefreshDelay : nil
    }
}
