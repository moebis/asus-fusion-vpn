import Foundation
import Testing
@testable import ASUSFusionVPN

@Test func runProcessFailsWhenProcessExceedsTimeout() throws {
    let client = SSHRouterClient(settings: testSettings())
    let start = Date()

    do {
        _ = try client.runProcess(
            executable: "/bin/sleep",
            arguments: ["5"],
            environment: [:],
            processTimeout: 0.1
        )
        throw ProcessTestError(message: "Expected process timeout.")
    } catch let error as SSHError {
        #expect(error.localizedDescription.contains("timed out"))
        #expect(Date().timeIntervalSince(start) < 2)
    }
}

@Test func runProcessPassesCustomEnvironment() throws {
    let client = SSHRouterClient(settings: testSettings())

    let output = try client.runProcess(
        executable: "/bin/sh",
        arguments: ["-c", "printf '%s' \"$ASUS_FUSION_VPN_TEST_VALUE\""],
        environment: ["ASUS_FUSION_VPN_TEST_VALUE": "router-value"]
    )

    #expect(output.trimmingCharacters(in: .newlines) == "router-value")
}

private func testSettings() -> AppSettings {
    AppSettings(
        routerHost: "192.168.1.1",
        sshPort: 22,
        username: "admin",
        password: "test",
        profileName: "Surfshark",
        vpnUnit: 5,
        selectedRegionEndpoint: "us-nyc.prod.surfshark.com",
        selectedRegionPublicKey: "public-key",
        favoriteRegionEndpoints: []
    )
}

private struct ProcessTestError: Error {
    let message: String
}
