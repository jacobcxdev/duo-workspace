import Foundation
import Security
import LocalAuthentication

public enum IdentityStore {
    private static let service = "DuoWorkspace.Identity.v2"

    public static func load(_ account: String, allowInteraction: Bool = true) throws -> Data? {
        var query = base(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        if !allowInteraction {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw IdentityError.keychain(status) }
        return data
    }

    public static func save(_ data: Data, account: String) throws {
        let query = base(account)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            #if !os(macOS)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            item[kSecAttrSynchronizable as String] = false
            #endif
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw IdentityError.keychain(added) }
        } else if status != errSecSuccess { throw IdentityError.keychain(status) }
    }

    public static func delete(_ account: String) throws {
        let status = SecItemDelete(base(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw IdentityError.keychain(status) }
    }

    private static func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
