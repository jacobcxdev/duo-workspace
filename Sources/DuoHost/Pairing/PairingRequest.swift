import Foundation

public struct PairingRequest: Identifiable, Equatable, Sendable {
    static let lifetime: TimeInterval = 60
    public let id: UUID
    public let name: String
    public let publicKeyPin: Data
    public let expiresAt: Date
    public let verificationCode: String
    let deadline: TimeInterval

    func isExpired(now: Date, uptime: TimeInterval) -> Bool {
        now >= expiresAt || uptime >= deadline
    }
}
