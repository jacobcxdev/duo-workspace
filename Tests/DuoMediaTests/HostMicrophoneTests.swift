import Foundation
import Testing
import DuoCore
@testable import DuoHost

@MainActor
struct HostMicrophoneTests {
    @Test func framesNeedCurrentStreamAndIncreasingSequence() async throws {
        let writer = TestMicrophoneWriter()
        let microphone = HostMicrophone(writer: writer)
        await microphone.setEnabled(MicrophoneControl(enabled: true, requestID: UUID()), allowed: true)
        let stream = try #require(microphone.status.stream)
        let packet = MicrophoneFrame(stream: stream, index: 1, samples: Data(repeating: 0, count: 1920))
        await microphone.receive(packet)
        await microphone.receive(packet)
        await microphone.receive(MicrophoneFrame(stream: UUID(), index: 2, samples: packet.samples))
        #expect(microphone.receivedFrames == 1)
        #expect(await writer.writes == 1)
        microphone.stop()
        await microphone.receive(MicrophoneFrame(stream: stream, index: 2, samples: packet.samples))
        #expect(!microphone.enabled && microphone.receivedFrames == 1)
    }

    @Test func viewOnlyRequestCannotStartWriter() async {
        let writer = TestMicrophoneWriter()
        let microphone = HostMicrophone(writer: writer)
        var status: MicrophoneStatus?
        microphone.changed = { status = $0 }
        await microphone.setEnabled(MicrophoneControl(enabled: true, requestID: UUID()), allowed: false)
        #expect(await writer.starts == 0)
        #expect(status?.failure == .controlRequired)
    }

    @Test func staleWriterGenerationCannotRestartAfterStop() async {
        let writer = MicrophoneWriter()
        await writer.stop(generation: 10)
        do { try await writer.start(generation: 9); Issue.record("Stale generation started") }
        catch { }
    }
}

private actor TestMicrophoneWriter: MicrophoneWriting {
    var writes = 0
    var starts = 0
    func available() -> Bool { true }
    func start(generation: UInt64) { starts += 1 }
    func write(_ frame: MicrophoneFrame, generation: UInt64) { writes += 1 }
    func stop(generation: UInt64) {}
}
