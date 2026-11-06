import Foundation
import Testing
import DuoCore
@testable import DuoWorkspace

@MainActor
struct MicrophoneClientTests {
    @Test func playbackAndMicrophoneShareOneAudioSession() throws {
        var modes: [ClientAudioSession.Mode] = []
        let session = ClientAudioSession(apply: { modes.append($0) })
        try session.setPlayback(true)
        try session.setMicrophone(true)
        try session.setPlayback(false)
        #expect(modes == [.playback, .microphone])
        try session.setMicrophone(false)
        #expect(modes == [.playback, .microphone, .off])
        try session.setMicrophone(true)
        try session.setPlayback(true)
        try session.setMicrophone(false)
        #expect(modes.suffix(2) == [.microphone, .playback])
    }

    @Test func captureNeedsPermissionAndMacAcknowledgement() async throws {
        let capture = FakeMicrophoneCapture()
        var requests: [MicrophoneControl] = []
        let microphone = SessionMicrophone(audioSession: ClientAudioSession(apply: { _ in }), permission: { true }, makeCapture: { capture.handler = $0; return capture })
        microphone.sendControl = { requests.append($0); return true }
        microphone.connected(supported: true)
        microphone.receive(MicrophoneStatus(available: true, enabled: false))
        microphone.enabled = true
        try await waitUntil { requests.last?.enabled == true }
        #expect(capture.starts == 0)
        let stream = UUID()
        microphone.receive(MicrophoneStatus(available: true, enabled: true, requestID: requests.last?.requestID, stream: stream))
        #expect(capture.starts == 1 && microphone.sending)
        var frames: [MicrophoneFrame] = []
        microphone.sendFrame = { frame, done in frames.append(frame); done(); return true }
        capture.handler?(Data(repeating: 0, count: 1920), 0.2, {})
        try await waitUntil { frames.count == 1 }
        #expect(frames.first?.stream == stream && frames.first?.isValid == true)
        microphone.enabled = false
        #expect(!microphone.sending && capture.stops == 1)
        capture.handler?(Data(repeating: 0, count: 1920), 0.2, {})
        try await Task.sleep(for: .milliseconds(20))
        #expect(frames.count == 1)
    }

    @Test func deniedPermissionNeverEnablesHostOrCapture() async throws {
        let capture = FakeMicrophoneCapture()
        var requests: [Bool] = []
        let microphone = SessionMicrophone(audioSession: ClientAudioSession(apply: { _ in }), permission: { false }, makeCapture: { _ in capture })
        microphone.sendControl = { requests.append($0.enabled); return true }
        microphone.connected(supported: true)
        microphone.receive(MicrophoneStatus(available: true, enabled: false))
        microphone.enabled = true
        try await waitUntil { !microphone.enabled }
        #expect(!requests.contains(true) && capture.starts == 0)
        #expect(microphone.message != nil)
    }

    @Test func cancellingPermissionRequestCannotStartCaptureLater() async throws {
        let capture = FakeMicrophoneCapture()
        var continuation: CheckedContinuation<Bool, Never>?
        var requests: [Bool] = []
        let microphone = SessionMicrophone(audioSession: ClientAudioSession(apply: { _ in }), permission: {
            await withCheckedContinuation { continuation = $0 }
        }, makeCapture: { _ in capture })
        microphone.sendControl = { requests.append($0.enabled); return true }
        microphone.connected(supported: true)
        microphone.receive(MicrophoneStatus(available: true, enabled: false))
        microphone.enabled = true
        try await waitUntil { continuation != nil }
        microphone.enabled = false
        continuation?.resume(returning: true)
        try await Task.sleep(for: .milliseconds(20))
        #expect(!requests.contains(true) && capture.starts == 0 && !microphone.sending)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        while !condition() {
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw CocoaError(.executableRuntimeMismatch) }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private final class FakeMicrophoneCapture: MicrophoneCapturing {
    var starts = 0
    var stops = 0
    var handler: MicrophonePacketHandler?
    @MainActor func start() { starts += 1 }
    @MainActor func stop() { stops += 1 }
}
