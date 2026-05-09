import Foundation

enum StatusRefreshPolicy {
    static let regularRefreshInterval: TimeInterval = 30
    static let regularRefreshRunLoopMode: RunLoop.Mode = .common

    static func followUpRefreshDelay(after state: VPNConnectionState) -> TimeInterval? {
        state == .connecting ? 5 : nil
    }
}
