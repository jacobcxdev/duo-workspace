public struct DisplayPixelSize: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public init(width: Int, height: Int) { self.width = width; self.height = height }
    public var isValid: Bool { (1...16_384).contains(width) && (1...16_384).contains(height) }
}
