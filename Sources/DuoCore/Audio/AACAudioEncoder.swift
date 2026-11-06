import AVFoundation

/// Used only on the capture audio queue.
public final class AACAudioEncoder {
    private let converter: AVAudioConverter
    private var stream = UUID()
    private var index: UInt64 = 0
    private var nextTime: TimeInterval?
    private var inputEnd: TimeInterval?

    public init(format: AVAudioFormat) throws {
        guard format.sampleRate == AudioStreamFormat.sampleRate, format.channelCount == AudioStreamFormat.channelCount,
              let output = AVAudioFormat(settings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: AudioStreamFormat.sampleRate, AVNumberOfChannelsKey: AudioStreamFormat.channelCount, AVEncoderBitRateKey: 128_000]),
              let converter = AVAudioConverter(from: format, to: output) else { throw WireError.invalidVideo }
        self.converter = converter
        converter.bitRate = 128_000
        converter.primeMethod = .none
    }

    public func encode(_ input: AVAudioPCMBuffer, time: TimeInterval) throws -> [AudioFrame] {
        guard input.frameLength > 0, input.frameLength <= 8192, time.isFinite, time >= 0 else { return [] }
        if let inputEnd, abs(time - inputEnd) > 0.1 {
            converter.reset(); stream = UUID(); index = 0; nextTime = nil
        }
        inputEnd = time + Double(input.frameLength) / AudioStreamFormat.sampleRate
        if nextTime == nil { nextTime = time }
        let output = AVAudioCompressedBuffer(format: converter.outputFormat, packetCapacity: 16,
                                            maximumPacketSize: converter.maximumOutputPacketSize)
        var provided = false
        var error: NSError?
        let result = converter.convert(to: output, error: &error) { _, status in
            guard !provided else { status.pointee = .noDataNow; return nil }
            provided = true; status.pointee = .haveData; return input
        }
        if result == .error { throw error ?? NSError(domain: "DuoAudio", code: 1) }
        guard let descriptions = output.packetDescriptions else { return [] }
        var frames: [AudioFrame] = []
        for offset in 0..<Int(output.packetCount) {
            let packet = descriptions[offset]
            let count = Int(packet.mDataByteSize), start = Int(packet.mStartOffset)
            guard count > 0, start >= 0, start + count <= Int(output.byteLength) else { throw WireError.invalidVideo }
            let frame = AudioFrame(stream: stream, index: index, time: nextTime ?? time,
                cookie: converter.magicCookie ?? Data(), data: Data(bytes: output.data.advanced(by: start), count: count))
            guard frame.isValid else { throw WireError.oversized }
            frames.append(frame); index &+= 1
            nextTime = (nextTime ?? time) + Double(AudioStreamFormat.framesPerPacket) / AudioStreamFormat.sampleRate
        }
        return frames
    }
}
