import AVFoundation
import Testing
import DuoCore

struct AudioRoundTripTests {
    @Test func nativeAACPreservesStereoSignalAndResetsAfterSilenceGap() throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let encoder = try AACAudioEncoder(format: format)
        let input = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096))
        input.frameLength = 4096
        let channels = try #require(input.floatChannelData)
        for i in 0..<4096 {
            channels[0][i] = sin(Float(i) * 2 * .pi * 440 / 48_000) * 0.4
            channels[1][i] = sin(Float(i) * 2 * .pi * 880 / 48_000) * 0.2
        }
        var frames: [AudioFrame] = []
        for i in 0..<4 { frames += try encoder.encode(input, time: 10 + Double(i * 4096) / 48_000) }
        #expect(frames.count >= 12)
        let first = try #require(frames.first)
        let decoder = try AACAudioDecoder(cookie: first.cookie)
        var energy: [Float] = [0, 0]
        var samples = 0
        for frame in frames {
            #expect(frame.isValid)
            let decoded = try decoder.decode(frame)
            if let data = decoded.floatChannelData {
                samples += Int(decoded.frameLength)
                for c in 0..<2 { for i in 0..<Int(decoded.frameLength) { energy[c] += data[c][i] * data[c][i] } }
            }
        }
        #expect(samples >= 12_000 && energy[0] > 100 && energy[1] > 10)
        #expect(energy[0] > energy[1] * 2)
        #expect(frames.reduce(0) { $0 + $1.data.count } < 4096 * 4 * 2 * 4 / 4)
        let restarted = try encoder.encode(input, time: 30)
        #expect(restarted.first?.stream != first.stream)
        #expect(restarted.first?.time == 30)
    }
}
