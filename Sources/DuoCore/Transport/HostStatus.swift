public struct HostStatus: Codable, Sendable {
    public var capabilities: Capabilities
    public var message: String
    public var captureRestarting: Bool?
    public init(capabilities: Capabilities, message: String, captureRestarting: Bool? = nil) {
        self.capabilities=capabilities; self.message=message; self.captureRestarting=captureRestarting
    }
}
