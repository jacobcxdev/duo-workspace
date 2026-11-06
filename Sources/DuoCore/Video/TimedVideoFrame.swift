import Foundation

public struct TimedVideoFrame: Sendable {
    public let time: TimeInterval
    public let data: Data
    public init(time: TimeInterval, data: Data) { self.time = time; self.data = data }

    public func encoded() -> Data {
        var bits = time.bitPattern.bigEndian
        var result = withUnsafeBytes(of: &bits) { Data($0) }
        result.append(data)
        return result
    }

    public init(encoded: Data) throws {
        guard encoded.count > 8 else { throw WireError.invalidVideo }
        let bits = encoded.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        time = Double(bitPattern: bits)
        guard time.isFinite, time >= 0 else { throw WireError.invalidVideo }
        data = Data(encoded.dropFirst(8))
    }
}
