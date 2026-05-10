import Foundation

enum AppSettingsValidator {
    static func validatedHost(_ value: String) throws -> String {
        let host = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            throw ValidationError(message: "Router host is required.")
        }
        guard isSafeToken(host), !host.hasPrefix("-") else {
            throw ValidationError(message: "Router host cannot contain whitespace, control characters, or start with '-'.")
        }
        return host
    }

    static func validatedUsername(_ value: String) throws -> String {
        let username = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else {
            throw ValidationError(message: "Username is required.")
        }
        guard isSafeToken(username), !username.hasPrefix("-") else {
            throw ValidationError(message: "Username cannot contain whitespace, control characters, or start with '-'.")
        }
        return username
    }

    static func validatedProfileName(_ value: String) throws -> String {
        let profileName = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profileName.isEmpty else {
            throw ValidationError(message: "Profile name is required.")
        }
        return profileName
    }

    static func validatedPassword(_ value: String) throws -> String {
        guard !value.isEmpty else {
            throw ValidationError(message: "Password is required.")
        }
        return value
    }

    static func validatedPort(_ value: String) throws -> Int {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmedValue), (1...65_535).contains(port) else {
            throw ValidationError(message: "SSH port must be a number from 1 to 65535.")
        }
        return port
    }

    static func validatedVPNUnit(_ value: String) throws -> Int {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let unit = Int(trimmedValue), unit > 0 else {
            throw ValidationError(message: "VPN unit must be a positive number.")
        }
        return unit
    }

    private static func isSafeToken(_ value: String) -> Bool {
        !value.contains(where: { character in
            character.isWhitespace || character.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        })
    }
}

struct ValidationError: LocalizedError, Sendable {
    let message: String

    var errorDescription: String? {
        message
    }
}
