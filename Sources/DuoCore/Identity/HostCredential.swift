import Foundation
import Security

public struct HostCredential: Codable, Equatable, Sendable {
    public let publicKeyPin: Data
    public init(publicKeyPin: Data) { self.publicKeyPin = publicKeyPin }
    public static func load(hostID: UUID) throws -> HostCredential? {
        guard let data = try IdentityStore.load("host.\(hostID.uuidString)") else { return nil }
        let credential = try JSONDecoder().decode(Self.self, from: data)
        guard credential.publicKeyPin.count == 32 else { throw IdentityError.invalidIdentity }
        return credential
    }
    public func save(hostID: UUID) throws {
        try IdentityStore.save(JSONEncoder().encode(self), account: "host.\(hostID.uuidString)")
    }
    public static func delete(hostID: UUID) throws {
        try IdentityStore.delete("host.\(hostID.uuidString)")
        // Older installations stored host credentials under the Pairing service.
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "DuoWorkspace.Pairing", kSecAttrAccount as String: hostID.uuidString]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw IdentityError.keychain(status) }
    }
}
