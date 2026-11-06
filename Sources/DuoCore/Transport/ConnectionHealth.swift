import Foundation

public struct ConnectionHealth: Sendable {
    public private(set) var startedAt: TimeInterval
    public private(set) var lastResponseAt: TimeInterval
    public private(set) var roundTripMilliseconds: Double?
    private var pending: (payload: Data, sentAt: TimeInterval)?
    private var sequence: UInt64 = 0

    public init(now: TimeInterval) {
        startedAt = now
        lastResponseAt = now
    }

    public mutating func ping(now: TimeInterval) -> Data {
        sequence &+= 1
        var bits = sequence.bigEndian
        let payload = withUnsafeBytes(of: &bits) { Data($0) }
        pending = (payload, now)
        return payload
    }

    @discardableResult
    public mutating func acknowledge(_ payload: Data, now: TimeInterval) -> Bool {
        guard let pending, pending.payload == payload, now >= pending.sentAt else { return false }
        lastResponseAt = now
        roundTripMilliseconds = (now - pending.sentAt) * 1_000
        self.pending = nil
        return true
    }

    public func isExpired(now: TimeInterval, timeout: TimeInterval = 10) -> Bool {
        now - lastResponseAt >= timeout
    }
}
