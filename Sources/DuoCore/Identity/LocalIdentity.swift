import Foundation
import CryptoKit
import Security

public final class LocalIdentity: @unchecked Sendable {
    public let securityIdentity: SecIdentity
    public let certificate: Data
    public let publicKeyPin: Data
    public var id: String { Self.identifier(publicKeyPin) }

    public static func loadOrCreate(account: String, allowInteraction: Bool = true, requireExisting: Bool = false) throws -> LocalIdentity {
        if let data = try IdentityStore.load(account, allowInteraction: allowInteraction) {
            return try LocalIdentity(privateKey: P256.Signing.PrivateKey(rawRepresentation: data))
        }
        guard !requireExisting else { throw IdentityError.missingIdentity }
        let key = P256.Signing.PrivateKey()
        try IdentityStore.save(key.rawRepresentation, account: account)
        return try LocalIdentity(privateKey: key)
    }

    public convenience init(now: Date = Date()) throws {
        try self.init(privateKey: P256.Signing.PrivateKey(), now: now)
    }

    public init(privateKey: P256.Signing.PrivateKey, now: Date = Date()) throws {
        certificate = try CertificateDER.certificate(key: privateKey, now: now)
        publicKeyPin = Data(SHA256.hash(data: privateKey.publicKey.x963Representation))
        var error: Unmanaged<CFError>?
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate, kSecAttrKeySizeInBits as String: 256]
        guard let key = SecKeyCreateWithData(privateKey.x963Representation as CFData, attributes as CFDictionary, &error),
              let cert = SecCertificateCreateWithData(nil, certificate as CFData),
              let identity = SecIdentityCreate(nil, cert, key) else { throw IdentityError.invalidIdentity }
        securityIdentity = identity
    }

    public static func pin(certificate data: Data) -> Data? {
        guard data.count <= 4096, let certificate = SecCertificateCreateWithData(nil, data as CFData),
              let key = SecCertificateCopyKey(certificate),
              let attributes = SecKeyCopyAttributes(key) as? [String: Any],
              attributes[kSecAttrKeyType as String] as? String == kSecAttrKeyTypeECSECPrimeRandom as String,
              attributes[kSecAttrKeySizeInBits as String] as? Int == 256,
              let bytes = SecKeyCopyExternalRepresentation(key, nil) as Data?, bytes.count == 65 else { return nil }
        return Data(SHA256.hash(data: bytes))
    }

    public static func identifier(_ pin: Data) -> String { pin.map { String(format: "%02x", $0) }.joined() }

    /// Signs only local revocations with a domain-separated payload.
    /// Retains the OS key if Keychain locks.
    public func signRevocationRecord(_ payload: Data) throws -> Data {
        var key: SecKey?
        guard payload.count <= 32 * 1024,
              SecIdentityCopyPrivateKey(securityIdentity, &key) == errSecSuccess, let key,
              let signature = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256,
                  Self.revocationMessage(payload) as CFData, nil) as Data? else { throw IdentityError.invalidRevocationRecord }
        return signature
    }

    public func verifyRevocationRecord(_ payload: Data, signature: Data) -> Bool {
        guard payload.count <= 32 * 1024, signature.count <= 80,
              let certificate = SecCertificateCreateWithData(nil, self.certificate as CFData),
              let key = SecCertificateCopyKey(certificate) else { return false }
        return SecKeyVerifySignature(key, .ecdsaSignatureMessageX962SHA256,
            Self.revocationMessage(payload) as CFData, signature as CFData, nil)
    }

    private static func revocationMessage(_ payload: Data) -> Data {
        Data("DuoWorkspace/local-revocation-record/v1\u{0}".utf8) + payload
    }

    public static func matches(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (a, b) in zip(lhs, rhs) { difference |= a ^ b }
        return difference == 0
    }
}
