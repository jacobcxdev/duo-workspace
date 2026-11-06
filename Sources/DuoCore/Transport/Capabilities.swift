public struct Capabilities: Codable, Equatable, Sendable {
    public var canCapture: Bool
    public var canControl: Bool
    public var canCreateDisplay: Bool
    public var canPlayAudio: Bool
    public init(canCapture: Bool, canControl: Bool, canCreateDisplay: Bool, canPlayAudio: Bool = false) {
        self.canCapture=canCapture; self.canControl=canControl
        self.canCreateDisplay=canCreateDisplay; self.canPlayAudio=canPlayAudio
    }
}
