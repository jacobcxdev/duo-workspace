import Foundation

public struct AuthorizationRequest: Codable, Sendable {
    public var version = 2
    public let deviceName: String
    public let invitationToken: Data?
    public let purpose: ConnectionPurpose?
    public init(deviceName: String, invitationToken: Data? = nil, purpose: ConnectionPurpose? = nil) {
        self.deviceName = deviceName; self.invitationToken = invitationToken; self.purpose = purpose
    }
    public var isValid: Bool {
        version == 2 && DeviceDisplayName.isValid(deviceName)
            && (invitationToken == nil || invitationToken?.count == 32)
            && (purpose != .files || invitationToken == nil)
    }
}
