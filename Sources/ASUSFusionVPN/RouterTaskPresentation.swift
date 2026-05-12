import Foundation

enum RouterTaskPresentation: Sendable {
    case statusRefresh
    case visibleAction

    var appliesBusyState: Bool {
        self == .visibleAction
    }

    var disablesControls: Bool {
        self == .visibleAction
    }

    var showsFailureAlert: Bool {
        self == .visibleAction
    }

    var clearsStatusOnFailure: Bool {
        self == .visibleAction
    }

    func failureTitle(hasLastStatus: Bool) -> String? {
        switch self {
        case .statusRefresh:
            hasLastStatus ? nil : "Status: Unavailable"
        case .visibleAction:
            "Status: Error"
        }
    }
}
