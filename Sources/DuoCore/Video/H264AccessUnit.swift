import Foundation

public struct H264AccessUnit: Sendable {
    public let isKeyframe: Bool

    /// Network H.264 uses four-byte, big-endian NAL lengths.
    public init?(_ data: Data) {
        guard !data.isEmpty, data.count <= PacketDecoder.maximumPayload else { return nil }
        let keyframe: Bool? = data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            var offset = 0
            var keyframe = false
            while offset < bytes.count {
                guard bytes.count - offset >= 5 else { return nil }
                let length = (0..<4).reduce(0) { ($0 << 8) | Int(bytes[offset + $1]) }
                guard length > 0, length <= bytes.count - offset - 4,
                      bytes[offset + 4] & 0x80 == 0,
                      (1...23).contains(bytes[offset + 4] & 0x1f) else { return nil }
                if bytes[offset + 4] & 0x1f == 5 { keyframe = true }
                offset += 4 + length
            }
            return keyframe
        }
        guard let keyframe else { return nil }
        isKeyframe = keyframe
    }
}
