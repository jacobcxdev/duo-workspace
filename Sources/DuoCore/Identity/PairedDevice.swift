import Foundation

public struct PairedDevice: Codable, Identifiable, Equatable, Sendable {
    public var id: String { LocalIdentity.identifier(publicKeyPin) }
    public let publicKeyPin: Data
    public var name: String
    public let pairedAt: Date
    public var revokedAt: Date?
    public var allowsControl: Bool
    public var isApproved: Bool { revokedAt == nil }
    public init(publicKeyPin: Data, name: String, now: Date = Date(), allowsControl: Bool = true) {
        self.publicKeyPin = publicKeyPin; self.name = name; pairedAt = now; self.allowsControl = allowsControl
    }
}
