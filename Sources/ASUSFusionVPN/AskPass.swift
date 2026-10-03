import Foundation

/// When OpenSSH needs the router password it runs `SSH_ASKPASS`, which points at this
/// app's own executable. In that mode the executable prints the password and exits
/// before any AppKit setup, which replaces the old `/usr/bin/expect` wrapper.
enum AskPass {
    static let modeEnvironmentKey = "ASUS_FUSION_VPN_ASKPASS"
    static let passwordEnvironmentKey = "ASUS_FUSION_VPN_ASKPASS_PASSWORD"

    /// Returns the exit code to use when this process was launched as an askpass helper.
    static func handleIfRequested(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        output: (String) -> Void = { FileHandle.standardOutput.write(Data($0.utf8)) }
    ) -> Int32? {
        guard environment[modeEnvironmentKey] == "1" else {
            return nil
        }

        // Only answer password prompts; refuse host-key confirmations and anything else.
        let prompt = arguments.dropFirst().joined(separator: " ")
        guard
            prompt.localizedCaseInsensitiveContains("password"),
            let password = environment[passwordEnvironmentKey],
            !password.isEmpty
        else {
            return 1
        }

        output(password + "\n")
        return 0
    }
}
