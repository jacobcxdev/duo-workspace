import Foundation

@MainActor
func waitForClientState(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !condition() {
        guard ContinuousClock.now < deadline else { throw ClientStateWaitTimeout() }
        try await Task.sleep(for: .milliseconds(5))
    }
}

@MainActor
func nextClientMainQueueTurn() async {
    await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
    }
}

private struct ClientStateWaitTimeout: Error {}
