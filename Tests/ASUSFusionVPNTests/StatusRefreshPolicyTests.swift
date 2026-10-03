import Foundation
import Testing
@testable import ASUSFusionVPN

@Test func connectingStatusRequestsShortFollowUpRefresh() {
    let delay = StatusRefreshPolicy.followUpRefreshDelay(after: .connecting)

    #expect(delay == 3)
}

@Test func terminalStatusesDoNotRequestFollowUpRefresh() {
    #expect(StatusRefreshPolicy.followUpRefreshDelay(after: .connected) == nil)
    #expect(StatusRefreshPolicy.followUpRefreshDelay(after: .disconnected) == nil)
    #expect(StatusRefreshPolicy.followUpRefreshDelay(after: .unknown) == nil)
}

@Test func regularRefreshTimerRunsInCommonModes() {
    #expect(StatusRefreshPolicy.regularRefreshRunLoopMode == .common)
}

@Test func menuOpenRefreshesOnlyWhenStatusIsStale() {
    let now = Date()

    #expect(StatusRefreshPolicy.shouldRefreshOnMenuOpen(lastRefreshDate: nil, now: now))
    #expect(!StatusRefreshPolicy.shouldRefreshOnMenuOpen(lastRefreshDate: now.addingTimeInterval(-3), now: now))
    #expect(StatusRefreshPolicy.shouldRefreshOnMenuOpen(lastRefreshDate: now.addingTimeInterval(-15), now: now))
}

@Test func regularRefreshTimerAllowsCoalescing() {
    #expect(StatusRefreshPolicy.regularRefreshTolerance > 0)
    #expect(StatusRefreshPolicy.regularRefreshTolerance < StatusRefreshPolicy.regularRefreshInterval)
}
