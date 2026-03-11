import Foundation
import Security

actor KeychainStore {
    static let shared = KeychainStore()

    private let service = AppConfig.keychainService

    // MARK: - Token management

    func saveToken(_ token: String) {
        save(key: AppConfig.tokenKeychainAccount, data: Data(token.utf8))
    }

    func getToken() -> String? {
        guard let data = load(key: AppConfig.tokenKeychainAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteToken() {
        delete(key: AppConfig.tokenKeychainAccount)
    }

    // MARK: - Generic Keychain operations

    private func save(key: String, data: Data) {
        delete(key: key)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func clearAll() {
        deleteToken()
    }
}
