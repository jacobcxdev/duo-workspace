import Foundation
import Testing
import DuoCore
@testable import DuoHost

@MainActor
struct ResizeLifecycleTests {
    @Test func stoppingCaptureWaitsForPendingStartupAndCancelsLateWork() async throws {
        let capture = CaptureEngine()
        var continuation: CheckedContinuation<Void, Never>?
        var createdStream = false
        let start = Task {
            try await capture.runStartup {
                await withCheckedContinuation { continuation = $0 }
                try Task.checkCancellation()
                createdStream = true
            }
        }
        for _ in 0..<100 where continuation == nil { await Task.yield() }
        let waiting = try #require(continuation)
        var stopped = false
        let firstStop = Task { await capture.stop(); stopped = true }
        let secondStop = Task { await capture.stop() }
        for _ in 0..<10 { await Task.yield() }
        #expect(!stopped)
        waiting.resume()
        await firstStop.value; await secondStop.value
        if case .success = await start.result { Issue.record("Canceled capture startup succeeded") }
        #expect(stopped && !createdStream)
    }

    @Test func releasingDuringResizePreservesClickTextAndReleaseOrder() {
        var buffer = DeferredInputBuffer()
        let accepted = [
            buffer.append(InputEvent(.keyDown, keyCode: 55), payloadSize: 32),
            buffer.append(InputEvent(.leftDown, x: 0.5, y: 0.5), payloadSize: 48),
            buffer.append(InputEvent(.text, text: "first"), payloadSize: 40),
            buffer.append(InputEvent(.releaseAll), payloadSize: 20),
            buffer.append(InputEvent(.text, text: " second"), payloadSize: 40)
        ]
        #expect(accepted.allSatisfy { $0 })
        let replay = buffer.take()
        #expect(replay.map(\.kind) == [.keyDown, .leftDown, .text, .releaseAll, .text])
        #expect(replay.compactMap(\.text).joined() == "first second")
        let remaining = buffer.take()
        #expect(remaining.isEmpty)
    }

    @Test func deferredInputStaysBoundedAfterReleaseAndDrain() {
        var buffer = DeferredInputBuffer()
        let full = buffer.append(InputEvent(.text, text: "saved"), payloadSize: 65_536)
        let overflow = buffer.append(InputEvent(.text, text: "overflow"), payloadSize: 1)
        let release = buffer.append(InputEvent(.releaseAll), payloadSize: 20)
        let afterRelease = buffer.append(InputEvent(.text, text: "overflow"), payloadSize: 1)
        #expect(full && !overflow && !release && !afterRelease)
        let saved = buffer.take()
        #expect(saved.count == 1)
        for _ in 0..<255 {
            let accepted = buffer.append(InputEvent(.keyDown, keyCode: 55), payloadSize: 32)
            #expect(accepted)
        }
        let released = buffer.append(InputEvent(.releaseAll), payloadSize: 20)
        let repeatedRelease = buffer.append(InputEvent(.releaseAll), payloadSize: 20)
        let tooMany = buffer.append(InputEvent(.text, text: "overflow"), payloadSize: 1)
        let queued = buffer.take()
        #expect(queued.count == 256 && queued.last?.kind == .releaseAll)
        let fresh = buffer.append(InputEvent(.text, text: "after release"), payloadSize: 40)
        #expect(!tooMany && released && repeatedRelease && fresh)
        let replay = buffer.take()
        #expect(replay.first?.text == "after release")
    }
}
