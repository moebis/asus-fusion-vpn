import Foundation
import Testing
@testable import ASUSFusionVPN

@Test func processRunnerFailsWhenProcessExceedsTimeout() async throws {
    let start = Date()

    await #expect(throws: ProcessTimeoutError.self) {
        _ = try await ProcessRunner.run(executable: "/bin/sleep", arguments: ["5"], timeout: 0.1)
    }
    #expect(Date().timeIntervalSince(start) < 2)
}

@Test func processRunnerPassesCustomEnvironment() async throws {
    let output = try await ProcessRunner.run(
        executable: "/bin/sh",
        arguments: ["-c", "printf '%s' \"$ASUS_FUSION_VPN_TEST_VALUE\""],
        environment: ["ASUS_FUSION_VPN_TEST_VALUE": "router-value"],
        timeout: 5
    )

    #expect(output.status == 0)
    #expect(output.standardOutput == "router-value")
}

@Test func processRunnerSeparatesOutputStreamsAndReportsExitStatus() async throws {
    let output = try await ProcessRunner.run(
        executable: "/bin/sh",
        arguments: ["-c", "echo out; echo err >&2; exit 3"],
        timeout: 5
    )

    #expect(output.status == 3)
    #expect(output.standardOutput == "out\n")
    #expect(output.standardError == "err\n")
}

@Test func processRunnerDrainsOutputLargerThanPipeBuffer() async throws {
    let output = try await ProcessRunner.run(
        executable: "/bin/sh",
        arguments: ["-c", "head -c 300000 /dev/zero | tr '\\0' 'x'"],
        timeout: 5
    )

    #expect(output.standardOutput.utf8.count == 300_000)
}

@Test func processRunnerStopsWhenCancelled() async throws {
    let start = Date()
    let task = Task {
        try await ProcessRunner.run(executable: "/bin/sleep", arguments: ["5"], timeout: 10)
    }
    try await Task.sleep(for: .milliseconds(100))
    task.cancel()

    await #expect(throws: CancellationError.self) {
        _ = try await task.value
    }
    #expect(Date().timeIntervalSince(start) < 2)
}

@Test func askPassAnswersOnlyPasswordPrompts() {
    var printed = ""
    let environment = [
        AskPass.modeEnvironmentKey: "1",
        AskPass.passwordEnvironmentKey: "secret"
    ]

    let passwordExit = AskPass.handleIfRequested(
        arguments: ["askpass", "admin@192.168.1.1's password: "],
        environment: environment,
        output: { printed += $0 }
    )
    #expect(passwordExit == 0)
    #expect(printed == "secret\n")

    printed = ""
    let hostKeyExit = AskPass.handleIfRequested(
        arguments: ["askpass", "Are you sure you want to continue connecting (yes/no/[fingerprint])?"],
        environment: environment,
        output: { printed += $0 }
    )
    #expect(hostKeyExit == 1)
    #expect(printed.isEmpty)

    #expect(AskPass.handleIfRequested(arguments: ["app"], environment: [:]) == nil)
}
