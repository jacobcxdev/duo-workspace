import Foundation

public struct MicrophoneControl: Codable, Sendable {
    public let enabled: Bool
    public let requestID: UUID
    public init(enabled: Bool, requestID: UUID) { self.enabled = enabled; self.requestID = requestID }
}

public struct MicrophoneStatus: Codable, Sendable {
    public enum Failure: String, Codable, Sendable { case deviceMissing, deviceBusy, controlRequired, streamFailed }
    public let available: Bool
    public let enabled: Bool
    public let requestID: UUID?
    public let stream: UUID?
    public let failure: Failure?
    public init(available: Bool, enabled: Bool, requestID: UUID? = nil, stream: UUID? = nil, failure: Failure? = nil) {
        self.available = available; self.enabled = enabled; self.requestID = requestID
        self.stream = stream; self.failure = failure
    }
    public var isValid: Bool { enabled ? available && stream != nil && failure == nil : stream == nil }
}

/// Signed 16-bit, little-endian mono PCM at 48 kHz, up to 4,096 frames.
public struct MicrophoneFrame: Codable, Sendable {
    public let stream: UUID
    public let index: UInt64
    public let samples: Data
    public init(stream: UUID, index: UInt64, samples: Data) {
        self.stream = stream; self.index = index; self.samples = samples
    }
    public var isValid: Bool { !samples.isEmpty && samples.count <= MicrophoneFormat.maximumPacketBytes && samples.count.isMultiple(of: MicrophoneFormat.bytesPerFrame) }
    public func floats() -> [Float] {
        guard isValid else { return [] }
        return samples.withUnsafeBytes { bytes in
            stride(from: 0, to: bytes.count, by: MicrophoneFormat.bytesPerFrame).map {
                Float(Int16(bitPattern: UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8)) / 32768
            }
        }
    }
    public static func pcm16(_ values: UnsafeBufferPointer<Float>) -> Data {
        var data = Data(capacity: values.count * MicrophoneFormat.bytesPerFrame)
        for sample in values {
            let value = sample.isFinite ? max(-1, min(1, sample)) : 0
            let integer = Int16((value * 32767).rounded())
            let bits = UInt16(bitPattern: integer)
            data.append(UInt8(bits & 255)); data.append(UInt8(bits >> 8))
        }
        return data
    }
}
