import Foundation

public struct DesktopState: Codable, Sendable {
    public let revision: UInt64
    public let desktop: DesktopSize
    public let ready: Bool
    public let accepted: Bool
    public let message: String
    public init(revision: UInt64, desktop: DesktopSize, ready: Bool, accepted: Bool, message: String) {
        self.revision = revision; self.desktop = desktop; self.ready = ready; self.accepted = accepted; self.message = message
    }
}
