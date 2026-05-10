import Foundation
import Security

enum RouterPasswordStore {
    private static let service = "com.moebis.asus-fusion-vpn"
    private static let account = "router-password"

    static func load() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
        guard
            let data = item as? Data,
            let password = String(data: data, encoding: .utf8)
        else {
            throw KeychainError(message: "Could not decode router password from Keychain.")
        }
        return password
    }

    static func save(_ password: String) throws {
        if password.isEmpty {
            try delete()
            return
        }

        let data = Data(password.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError(status: updateStatus)
        }

        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(status: addStatus)
        }
    }

    static func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

struct KeychainError: LocalizedError, Sendable {
    let status: OSStatus?
    let message: String?

    init(status: OSStatus) {
        self.status = status
        self.message = nil
    }

    init(message: String) {
        self.status = nil
        self.message = message
    }

    var errorDescription: String? {
        if let message {
            return message
        }
        if let status {
            let description = SecCopyErrorMessageString(status, nil) as String?
            return description ?? "Keychain error \(status)."
        }
        return "Unknown Keychain error."
    }
}
