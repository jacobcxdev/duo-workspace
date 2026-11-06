import AVFoundation
import DuoCore

typealias MicrophonePacketHandler = @Sendable (Data, Float, @escaping @Sendable () -> Void) -> Void

protocol MicrophoneCapturing: AnyObject {
    @MainActor func start() throws
    @MainActor func stop()
}

final class MicrophoneCapture: MicrophoneCapturing, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "DuoWorkspace.MicrophoneCapture")
    private let processingSlots = DispatchSemaphore(value: 2)
    private let packetSlots = DispatchSemaphore(value: 4)
    private var state: Conversion?
    private var tapInstalled = false
    private let received: @Sendable (Data, Float, @escaping @Sendable () -> Void) -> Void

    init(received: @escaping @Sendable (Data, Float, @escaping @Sendable () -> Void) -> Void) {
        self.received = received
    }

    @MainActor
    func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0,
              let target = AVAudioFormat(standardFormatWithSampleRate: MicrophoneFormat.sampleRate, channels: MicrophoneFormat.channelCount),
              let converter = AVAudioConverter(from: format, to: target) else { throw CaptureError.format }
        let conversion = Conversion(converter: converter, target: target)
        queue.sync { state = conversion }
        let bufferSize = AVAudioFrameCount(max(64, min(2048, (format.sampleRate / 50).rounded())))
        installInputTap(input, bufferSize: bufferSize, format: format, conversion: conversion)
        tapInstalled = true
        engine.prepare()
        do { try engine.start() }
        catch { stop(); throw error }
    }

    @MainActor
    func stop() {
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        engine.stop()
        queue.sync { state = nil }
    }

    private nonisolated func installInputTap(_ input: AVAudioInputNode, bufferSize: AVAudioFrameCount,
                                             format: AVAudioFormat, conversion: Conversion) {
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { @Sendable [weak self] buffer, _ in
            self?.enqueue(buffer, conversion: conversion)
        }
    }

    private func enqueue(_ buffer: AVAudioPCMBuffer, conversion: Conversion) {
        guard buffer.frameLength > 0, buffer.frameLength <= 8192,
              processingSlots.wait(timeout: .now()) == .success else { return }
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
            processingSlots.signal(); return
        }
        copy.frameLength = buffer.frameLength
        let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffer.audioBufferList))
        let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for (from, to) in zip(source, destination) {
            if let src = from.mData, let dst = to.mData { memcpy(dst, src, Int(min(from.mDataByteSize, to.mDataByteSize))) }
        }
        let packet = CapturedBuffer(buffer: copy)
        queue.async { [self] in
            defer { processingSlots.signal() }
            guard state === conversion else { return }
            let capacity = AVAudioFrameCount(ceil(Double(packet.buffer.frameLength) * MicrophoneFormat.sampleRate / packet.buffer.format.sampleRate) + 32)
            guard let output = AVAudioPCMBuffer(pcmFormat: conversion.target, frameCapacity: capacity) else { return }
            var supplied = false
            var error: NSError?
            let result = conversion.converter.convert(to: output, error: &error) { _, status in
                guard !supplied else { status.pointee = .noDataNow; return nil }
                supplied = true; status.pointee = .haveData; return packet.buffer
            }
            guard result != .error, let channel = output.floatChannelData?[0] else { return }
            conversion.pending.append(MicrophoneFrame.pcm16(UnsafeBufferPointer(start: channel, count: Int(output.frameLength))))
            while conversion.pending.count >= Int(MicrophoneFormat.sampleRate / 50) * MicrophoneFormat.bytesPerFrame {
                let count = min(MicrophoneFormat.maximumPacketBytes, conversion.pending.count - conversion.pending.count % MicrophoneFormat.bytesPerFrame)
                let data = Data(conversion.pending.prefix(count)); conversion.pending.removeFirst(count)
                guard packetSlots.wait(timeout: .now()) == .success else { continue }
                let bytes = [UInt8](data)
                var peak: Float = 0
                for offset in stride(from: 0, to: bytes.count, by: MicrophoneFormat.bytesPerFrame) {
                    peak = max(peak, abs(Float(Int16(bitPattern: UInt16(bytes[offset]) | UInt16(bytes[offset+1]) << 8)) / 32768))
                }
                let slots = packetSlots
                received(data, peak, { slots.signal() })
            }
        }
    }

    private final class Conversion: @unchecked Sendable {
        let converter: AVAudioConverter
        let target: AVAudioFormat
        var pending = Data()
        init(converter: AVAudioConverter, target: AVAudioFormat) { self.converter = converter; self.target = target }
    }
    private struct CapturedBuffer: @unchecked Sendable { let buffer: AVAudioPCMBuffer }
    enum CaptureError: Error { case format }
}
