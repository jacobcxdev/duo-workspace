import Foundation
import Security

enum SecureRandom {
    static func bytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw IdentityError.randomGeneration(status) }
        return Data(bytes)
    }
}
