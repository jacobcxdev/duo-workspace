import Foundation

public struct DesktopResizeRequest: Codable, Sendable {
    public let revision: UInt64
    public let desktop: DesktopSize
    public init(revision: UInt64, desktop: DesktopSize) { self.revision = revision; self.desktop = desktop }
    public var isValid: Bool { revision > 0 && desktop.isValid }
}
