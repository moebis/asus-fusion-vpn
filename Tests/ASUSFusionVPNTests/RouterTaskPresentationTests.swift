import Testing
@testable import ASUSFusionVPN

@Test func statusRefreshPresentationDoesNotExposePollingState() {
    let presentation = RouterTaskPresentation.statusRefresh

    #expect(!presentation.appliesBusyState)
    #expect(!presentation.disablesControls)
    #expect(!presentation.showsFailureAlert)
    #expect(!presentation.clearsStatusOnFailure)
    #expect(presentation.failureTitle(hasLastStatus: true) == nil)
    #expect(presentation.failureTitle(hasLastStatus: false) == "Status: Unavailable")
}

@Test func visibleActionPresentationStillShowsProgressAndErrors() {
    let presentation = RouterTaskPresentation.visibleAction

    #expect(presentation.appliesBusyState)
    #expect(presentation.disablesControls)
    #expect(presentation.showsFailureAlert)
    #expect(presentation.clearsStatusOnFailure)
    #expect(presentation.failureTitle(hasLastStatus: true) == "Status: Error")
}
