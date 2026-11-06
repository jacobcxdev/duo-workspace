import Foundation
import DuoCore
import DuoMicrophoneBridge

protocol MicrophoneWriting: Actor {
    func available() async -> Bool
    func start(generation: UInt64) async throws
    func write(_ frame: MicrophoneFrame, generation: UInt64) async throws
    func stop(generation: UInt64) async
}

actor MicrophoneWriter: MicrophoneWriting {
    private var device: AudioObjectID = 0
    private var token = [UInt8](repeating: 0, count: 16)
    private var generation: UInt64 = 0

    func available() -> Bool { DuoMicFindDevice() != 0 }

    func start(generation expected: UInt64) throws {
        guard expected >= generation else { throw WriterError.stopped }
        stop(generation: expected)
        let found = DuoMicFindDevice()
        guard found != 0 else { throw WriterError.missing }
        var uuid = UUID().uuid
        token = withUnsafeBytes(of: &uuid) { Array($0) }
        guard DuoMicSend(found, DUO_MIC_OPEN, token, nil, 0) == 0 else { throw WriterError.busy }
        device = found
    }

    func write(_ frame: MicrophoneFrame, generation expected: UInt64) throws {
        guard expected == generation, device != 0, frame.isValid else { throw WriterError.stopped }
        let samples = frame.floats()
        let result = samples.withUnsafeBufferPointer { DuoMicSend(device, DUO_MIC_WRITE, token, $0.baseAddress, UInt32($0.count)) }
        guard result == 0 else { stop(generation: expected); throw WriterError.stopped }
    }

    func stop(generation expected: UInt64) {
        guard expected >= generation else { return }
        generation = expected
        if device != 0 { _ = DuoMicSend(device, DUO_MIC_CLOSE, token, nil, 0) }
        device = 0
    }

    enum WriterError: Error { case missing, busy, stopped }
}
