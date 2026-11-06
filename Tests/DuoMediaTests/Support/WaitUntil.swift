import Foundation

@MainActor
func waitUntil(_ condition: () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(6))
    while !condition() {
        guard clock.now < deadline else { throw TestDeadlineExceeded() }
        try await clock.sleep(for: .milliseconds(20))
    }
}

private struct TestDeadlineExceeded: Error {}
