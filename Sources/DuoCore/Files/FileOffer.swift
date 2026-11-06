import Foundation

public struct FileOffer: Codable, Equatable, Sendable {
    public static let maximumSize: UInt64 = 2 * 1024 * 1024 * 1024
    public let name: String
    public let size: UInt64
    public init(name: String, size: UInt64) { self.name = name; self.size = size }
    public var isValid: Bool {
        !name.isEmpty && name != "." && name != ".." && name.utf8.count <= 240 && size <= Self.maximumSize
            && !name.contains("/") && !name.contains("\\") && !name.contains(":")
            && !name.unicodeScalars.contains {
                $0.value < 32 || (127...159).contains($0.value) || (0x2028...0x202E).contains($0.value)
                    || (0x2066...0x2069).contains($0.value)
            }
    }
}
