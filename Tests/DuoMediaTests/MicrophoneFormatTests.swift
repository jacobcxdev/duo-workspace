import Foundation
import Testing
import DuoCore
import DuoMicrophoneBridge

struct MicrophoneFormatTests {
    @Test func networkCaptureAndHALAgreeOnMicrophoneFormat() {
        #expect(MicrophoneFormat.sampleRate == Double(DUO_MIC_SAMPLE_RATE))
        #expect(MicrophoneFormat.channelCount == UInt32(DUO_MIC_CHANNEL_COUNT))
        #expect(MicrophoneFormat.bitsPerSample == Int(DUO_MIC_WIRE_BITS_PER_SAMPLE))
        #expect(MicrophoneFormat.maximumFrames == Int(DUO_MIC_MAX_FRAMES))
        #expect(MicrophoneFormat.maximumPacketBytes == 8192)
        #expect(MicrophoneFrame(stream: UUID(), index: 0,
            samples: Data(repeating: 0, count: Int(DUO_MIC_MAX_FRAMES) * 2)).isValid)
        #expect(!MicrophoneFrame(stream: UUID(), index: 0,
            samples: Data(repeating: 0, count: (Int(DUO_MIC_MAX_FRAMES) + 1) * 2)).isValid)
    }
}
