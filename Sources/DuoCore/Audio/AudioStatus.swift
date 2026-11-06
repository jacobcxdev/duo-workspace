import Foundation

public struct AudioStatus: Codable, Sendable {
    public let enabled: Bool
    public let failed: Bool
    public let requestID: UUID?
    public let canMuteMac: Bool?
    public let macMuteEnabled: Bool?
    public let macMuteFailed: Bool?
    public init(enabled: Bool, failed: Bool = false, requestID: UUID? = nil,
                canMuteMac: Bool? = nil, macMuteEnabled: Bool? = nil, macMuteFailed: Bool? = nil) {
        self.enabled = enabled; self.failed = failed; self.requestID = requestID
        self.canMuteMac = canMuteMac; self.macMuteEnabled = macMuteEnabled; self.macMuteFailed = macMuteFailed
    }
}
