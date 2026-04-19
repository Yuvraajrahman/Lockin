import Foundation
import Security

/// Tiny wrapper around the macOS Keychain for storing the GitHub PAT.
/// Items are stored as generic passwords scoped to the app's bundle id.
enum KeychainService {
    static let service = "com.rogue.ilockin"
    static let githubTokenAccount = "github.pat"

    @discardableResult
    static func setGithubToken(_ token: String?) -> Bool {
        if let token, !token.isEmpty {
            return set(token, account: githubTokenAccount)
        } else {
            return delete(account: githubTokenAccount)
        }
    }

    static func getGithubToken() -> String? {
        get(account: githubTokenAccount)
    }

    // MARK: - Generic helpers

    private static func set(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        // Try update first, then add.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
        return false
    }

    private static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    @discardableResult
    private static func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
