import Foundation

public struct AdmissionLimiter: Sendable {
    private struct Bucket: Sendable { var tokens: Double; var updatedAt: TimeInterval }
    private var buckets: [String: Bucket] = [:]
    public init() {}
    public mutating func allow(_ peer: String, now: TimeInterval) -> Bool {
        if buckets.count >= 128, buckets[peer] == nil, let oldest = buckets.min(by: { $0.value.updatedAt < $1.value.updatedAt })?.key { buckets.removeValue(forKey: oldest) }
        var bucket = buckets[peer] ?? Bucket(tokens: 12, updatedAt: now)
        bucket.tokens = min(12, bucket.tokens + max(0, now - bucket.updatedAt) / 5)
        bucket.updatedAt = now
        let allowed = bucket.tokens >= 1
        if allowed { bucket.tokens -= 1 }
        buckets[peer] = bucket
        return allowed
    }
}
