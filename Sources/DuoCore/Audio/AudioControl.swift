import Foundation

public struct AudioControl: Codable, Sendable {
    public let enabled: Bool
    public let muteMac: Bool?
    public let requestID: UUID?
    public init(enabled: Bool, muteMac: Bool? = nil, requestID: UUID? = nil) {
        self.enabled = enabled; self.muteMac = muteMac; self.requestID = requestID
    }
}
