enum StatusDisplayUpdatePolicy {
    static func shouldUpdateStateChrome(
        previousDisplayState: VPNConnectionState?,
        nextDisplayState: VPNConnectionState,
        previousProfileName: String?,
        nextProfileName: String
    ) -> Bool {
        previousDisplayState != nextDisplayState || previousProfileName != nextProfileName
    }

    static func shouldUpdateStatusDetails(
        previousStatus: VPNStatus?,
        nextStatus: VPNStatus
    ) -> Bool {
        previousStatus != nextStatus
    }
}
