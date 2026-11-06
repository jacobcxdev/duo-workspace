import Foundation
import Observation
import DuoCore

@MainActor @Observable
public final class HostMicrophone {
    public private(set) var available = false
    public private(set) var enabled = false
    public private(set) var receivedFrames = 0
    @ObservationIgnored var changed: ((MicrophoneStatus) -> Void)?
    @ObservationIgnored private let writer: any MicrophoneWriting
    @ObservationIgnored private var requestID: UUID?
    @ObservationIgnored private var stream: UUID?
    @ObservationIgnored private var lastIndex: UInt64?
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var lastPacket = 0.0
    @ObservationIgnored private var cleanup: Task<Void, Never>?

    public init() { writer = MicrophoneWriter() }
    init(writer: any MicrophoneWriting) { self.writer = writer }

    func refresh() async {
        let current = await writer.available()
        if available != current { available = current; changed?(status) }
        if enabled && !current {
            stop(); changed?(MicrophoneStatus(available: false, enabled: false, requestID: requestID, failure: .deviceMissing))
        }
        let deadline = lastIndex == nil ? 5.0 : 1.0
        if enabled && ProcessInfo.processInfo.systemUptime - lastPacket > deadline {
            stop(); changed?(MicrophoneStatus(available: available, enabled: false, requestID: requestID, failure: .streamFailed))
        }
    }

    var status: MicrophoneStatus { MicrophoneStatus(available: available, enabled: enabled, requestID: requestID, stream: stream) }

    func setEnabled(_ request: MicrophoneControl, allowed: Bool) async {
        stop(); requestID = request.requestID
        let token = generation
        await cleanup?.value
        guard token == generation else { return }
        available = await writer.available()
        guard token == generation else { return }
        guard request.enabled else { changed?(status); return }
        guard allowed else { changed?(MicrophoneStatus(available: available, enabled: false, requestID: requestID, failure: .controlRequired)); return }
        do {
            try await writer.start(generation: token)
            guard token == generation else { await writer.stop(generation: token); return }
            enabled = true; stream = UUID(); lastIndex = nil; receivedFrames = 0
            lastPacket = ProcessInfo.processInfo.systemUptime
            changed?(status)
        } catch {
            guard token == generation else { return }
            changed?(MicrophoneStatus(available: available, enabled: false, requestID: requestID,
                failure: available ? .deviceBusy : .deviceMissing))
        }
    }

    func receive(_ frame: MicrophoneFrame) async {
        guard enabled, frame.stream == stream, frame.isValid,
              lastIndex.map({ frame.index > $0 }) ?? true else { return }
        let token = generation
        do {
            try await writer.write(frame, generation: token)
            guard token == generation else { return }
            lastIndex = frame.index; lastPacket = ProcessInfo.processInfo.systemUptime
            receivedFrames += 1
        } catch {
            guard token == generation else { return }
            stop()
            changed?(MicrophoneStatus(available: available, enabled: false, requestID: requestID, failure: .streamFailed))
        }
    }

    func stop() {
        generation &+= 1; enabled = false; stream = nil; lastIndex = nil
        let token = generation
        let previous = cleanup
        cleanup = Task { await previous?.value; await writer.stop(generation: token) }
    }
}
