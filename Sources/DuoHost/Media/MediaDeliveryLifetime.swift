import Foundation

@MainActor
final class MediaDeliveryLifetime {
    enum StartupError: Error { case timedOut }
    private(set) var isActive = true
    private var delivered = false
    private var failure: Error?
    private var retirement: Task<Void, Never>?
    private let frames: AsyncThrowingStream<Void, Error>
    private let delivery: AsyncThrowingStream<Void, Error>.Continuation

    init() { (frames, delivery) = AsyncThrowingStream.makeStream(bufferingPolicy: .bufferingNewest(1)) }

    func firstFrame() {
        guard isActive, !delivered else { return }
        delivered = true; delivery.yield(()); delivery.finish()
    }

    func fail(_ error: Error) { failure = error; delivery.finish(throwing: error) }

    func retire() {
        isActive = false
        delivery.finish(throwing: CancellationError())
    }

    func waitForFirstFrame(until deadline: TimeInterval) async throws {
        guard isActive else { throw CancellationError() }
        if let failure { throw failure }
        if delivered { return }
        let stream = frames
        let remaining = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                guard try await iterator.next() != nil else { throw CancellationError() }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(remaining))
                throw StartupError.timedOut
            }
            defer { group.cancelAll() }
            _ = try await group.next()
        }
        guard isActive else { throw CancellationError() }
        if let failure { throw failure }
    }

    func finish(_ drain: @escaping @MainActor () async -> Void) async {
        if let retirement { await retirement.value; return }
        retire()
        let task = Task { await drain() }
        retirement = task
        await task.value
    }
}
