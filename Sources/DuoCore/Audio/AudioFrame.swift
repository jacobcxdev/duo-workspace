import Foundation

/// One AAC-LC packet: 1,024 stereo samples at 48 kHz. Each capture has a new ID.
public struct AudioFrame: Codable, Sendable {
    public let stream: UUID
    public let index: UInt64
    public let time: TimeInterval
    public let cookie: Data
    public let data: Data

    public init(stream: UUID, index: UInt64, time: TimeInterval, cookie: Data, data: Data) {
        self.stream = stream; self.index = index; self.time = time; self.cookie = cookie; self.data = data
    }

    public var isValid: Bool {
        time.isFinite && time >= 0 && cookie.count <= 4096 && !data.isEmpty && data.count <= 16 * 1024
    }
}
