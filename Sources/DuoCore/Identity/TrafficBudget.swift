import Foundation

/// Bounds callback work before packets can queue work on the UI actor.
public struct TrafficBudget: Sendable {
    private var tokens: Double
    private let capacity: Double
    private let rate: Double
    private var lastUpdate: TimeInterval?
    public init(capacity: Int = 600, perSecond: Int = 300) {
        self.capacity = Double(capacity); rate = Double(perSecond); tokens = Double(capacity)
    }
    public mutating func consume(now: TimeInterval) -> Bool {
        if let lastUpdate { tokens = min(capacity, tokens + max(0, now - lastUpdate) * rate) }
        lastUpdate = now
        guard tokens >= 1 else { return false }
        tokens -= 1
        return true
    }
}
