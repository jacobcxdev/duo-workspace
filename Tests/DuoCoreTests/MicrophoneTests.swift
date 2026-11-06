import Foundation
import Testing
@testable import DuoCore

struct MicrophoneTests {
    @Test func pcmIsBoundedAndClampsInvalidSamples() throws {
        let values: [Float] = [-2, -1, 0, 0.5, 1, 2, .nan, .infinity]
        let data = values.withUnsafeBufferPointer { MicrophoneFrame.pcm16($0) }
        let frame = MicrophoneFrame(stream: UUID(), index: 1, samples: data)
        #expect(frame.isValid && data.count == 16)
        let decoded = frame.floats()
        for (value, expected) in zip(decoded, [Float(-1),-1,0,0.5,1,1,0,0]) {
            #expect(abs(value - expected) < 0.0001)
        }
        #expect(!MicrophoneFrame(stream: UUID(), index: 1, samples: Data()).isValid)
        #expect(!MicrophoneFrame(stream: UUID(), index: 1, samples: Data([1])).isValid)
        #expect(!MicrophoneFrame(stream: UUID(), index: 1, samples: Data(repeating: 0, count: 8194)).isValid)
        let encoded = try JSONEncoder().encode(frame)
        #expect(try JSONDecoder().decode(MicrophoneFrame.self, from: encoded).samples == data)
    }

    @Test func enabledStatusRequiresAvailableDeviceAndStream() {
        #expect(MicrophoneStatus(available: true, enabled: true, stream: UUID()).isValid)
        #expect(!MicrophoneStatus(available: false, enabled: true, stream: UUID()).isValid)
        #expect(!MicrophoneStatus(available: true, enabled: true).isValid)
        #expect(!MicrophoneStatus(available: true, enabled: false, stream: UUID()).isValid)
    }
}
