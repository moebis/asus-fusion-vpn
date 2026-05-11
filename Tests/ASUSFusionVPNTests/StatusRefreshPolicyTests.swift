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
