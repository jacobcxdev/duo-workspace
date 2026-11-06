import Foundation
import CryptoKit

public struct PairingInvitation: Codable, Equatable, Sendable {
    public static let lifetime: TimeInterval = 300
    public var version = 2
    public let name: String
    public private(set) var address: String
    public private(set) var port: UInt16
    public let hostPin: Data
    public let token: Data
    public let expiresAt: Date

    public init(name: String, address: String, port: UInt16 = 47991, hostPin: Data, now: Date = Date()) throws {
        guard let address = HostAddress.normalized(address), hostPin.count == 32, port != 0,
              DeviceDisplayName.isValid(String(name.prefix(80))) else { throw IdentityError.invalidInvitation }
        self.name = String(name.prefix(80)); self.address = address; self.port = port; self.hostPin = hostPin
        token = try SecureRandom.bytes(count: 32); expiresAt = now.addingTimeInterval(Self.lifetime)
    }

    public func link() throws -> String {
        let data = try JSONEncoder().encode(self)
        let encoded = data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "duoworkspace://pair?invite=\(encoded)"
    }

    /// Routing may change; the invitation's identity, token and expiry must not.
    public func overridingAddress(_ address: String, port: UInt16? = nil) throws -> Self {
        guard let address = HostAddress.normalized(address), port != 0 else { throw IdentityError.invalidInvitation }
        var result = self
        result.address = address
        result.port = port ?? self.port
        return result
    }

    public static func parse(_ string: String, now: Date = Date()) throws -> Self {
        guard string.utf8.count <= 8192,
              let url = URLComponents(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "duoworkspace", url.host == "pair", url.path.isEmpty,
              url.user == nil, url.password == nil, url.port == nil, url.fragment == nil,
              let items = url.queryItems, items.count == 1, items[0].name == "invite", var encoded = items[0].value else { throw IdentityError.invalidInvitation }
        encoded = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded), let value = try? JSONDecoder().decode(Self.self, from: data),
              value.version == 2, value.hostPin.count == 32, value.token.count == 32,
              value.port != 0, HostAddress.normalized(value.address) == value.address,
              DeviceDisplayName.isValid(value.name) else { throw IdentityError.invalidInvitation }
        guard value.expiresAt > now, value.expiresAt.timeIntervalSince(now) <= 2 * Self.lifetime else { throw IdentityError.expiredInvitation }
        return value
    }

    public static func verificationCode(hostPin: Data, devicePin: Data, sessionSecret: Data) -> String {
        let digest = SHA256.hash(data: Data("DuoWorkspace verification v2".utf8) + hostPin + devicePin + sessionSecret)
        let number = digest.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } % 1_000_000
        return String(format: "%06u", number)
    }
}
