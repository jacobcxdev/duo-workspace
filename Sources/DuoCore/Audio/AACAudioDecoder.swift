import AVFoundation

public final class AACAudioDecoder {
    public let format: AVAudioFormat
    private let converter: AVAudioConverter

    public init(cookie: Data) throws {
        guard cookie.count <= 4096,
              let input = AVAudioFormat(settings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: AudioStreamFormat.sampleRate, AVNumberOfChannelsKey: AudioStreamFormat.channelCount]),
              let output = AVAudioFormat(standardFormatWithSampleRate: AudioStreamFormat.sampleRate, channels: AudioStreamFormat.channelCount),
              let converter = AVAudioConverter(from: input, to: output) else { throw WireError.invalidVideo }
        self.converter = converter; format = output
        converter.magicCookie = cookie
        converter.primeMethod = .none
    }

    public func decode(_ frame: AudioFrame) throws -> AVAudioPCMBuffer {
        guard frame.isValid else { throw WireError.oversized }
        let input = AVAudioCompressedBuffer(format: converter.inputFormat, packetCapacity: 1, maximumPacketSize: frame.data.count)
        input.packetCount = 1; input.byteLength = UInt32(frame.data.count)
        frame.data.withUnsafeBytes { input.data.copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
        input.packetDescriptions?.pointee = AudioStreamPacketDescription(mStartOffset: 0, mVariableFramesInPacket: AudioStreamFormat.framesPerPacket,
                                                                         mDataByteSize: UInt32(frame.data.count))
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2048) else { throw WireError.oversized }
        var provided = false
        var error: NSError?
        let result = converter.convert(to: output, error: &error) { _, status in
            guard !provided else { status.pointee = .noDataNow; return nil }
            provided = true; status.pointee = .haveData; return input
        }
        if result == .error { throw error ?? NSError(domain: "DuoAudio", code: 2) }
        return output
    }
}
