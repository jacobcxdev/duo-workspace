import Foundation

/// Limit service restarts across reconnects as well as within one session.
struct CaptureRecoveryBudget {
    private var attempts: [TimeInterval] = []

    mutating func beginAttempt(now: TimeInterval) -> Bool {
        guard now.isFinite, now >= 0, attempts.last.map({ now >= $0 }) ?? true else { return false }
        attempts.removeAll { now - $0 >= 60 }
        guard attempts.count < 2 else { return false }
        attempts.append(now)
        return true
    }
}
