import XCTest
@testable import DuoHost

@MainActor
final class MediaDeliveryLifetimeTests: XCTestCase {
    func testRetirementRejectsQueuedFrameAndUnblocksWaiter() async {
        let lifetime = MediaDeliveryLifetime()
        let waiting = Task { try await lifetime.waitForFirstFrame(until: ProcessInfo.processInfo.systemUptime + 10) }
        await Task.yield()
        lifetime.retire()
        lifetime.firstFrame()
        do { try await waiting.value; XCTFail("Retired delivery succeeded") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testCaptureFailureWinsEvenAfterFirstFrame() async {
        let lifetime = MediaDeliveryLifetime()
        lifetime.firstFrame()
        lifetime.fail(CocoaError(.fileReadUnknown))
        do { try await lifetime.waitForFirstFrame(until: ProcessInfo.processInfo.systemUptime + 10); XCTFail("Capture failure lost") }
        catch { XCTAssertEqual((error as NSError).code, CocoaError.fileReadUnknown.rawValue) }
    }

    func testDeadlineAndCancellationDoNotWaitForCapture() async {
        let expired = MediaDeliveryLifetime()
        do { try await expired.waitForFirstFrame(until: 0); XCTFail("Missing deadline") }
        catch { XCTAssertTrue(error is MediaDeliveryLifetime.StartupError) }
        let pending = MediaDeliveryLifetime()
        let waiting = Task { try await pending.waitForFirstFrame(until: ProcessInfo.processInfo.systemUptime + 10) }
        waiting.cancel()
        do { try await waiting.value; XCTFail("Cancellation ignored") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testConcurrentStopsShareDrainAndRejectDeliveryImmediately() async {
        let lifetime = MediaDeliveryLifetime()
        let gate = AsyncStream<Void>.makeStream()
        let started = AsyncStream<Void>.makeStream()
        var drains = 0
        let first = Task {
            await lifetime.finish {
                drains += 1
                started.continuation.yield(()); started.continuation.finish()
                for await _ in gate.stream { break }
            }
        }
        for await _ in started.stream { break }
        let second = Task { await lifetime.finish { drains += 1 } }
        XCTAssertFalse(lifetime.isActive)
        XCTAssertEqual(drains, 1)
        gate.continuation.yield(()); gate.continuation.finish()
        await first.value; await second.value
        XCTAssertEqual(drains, 1)
    }
}
