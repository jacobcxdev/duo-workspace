public struct InputEvent: Codable, Sendable {
    public static let maximumTextBytes = 8192
    public enum Kind: String, Codable, Sendable { case move, leftDown, leftUp, rightClick, scroll, text, keyDown, keyUp, releaseAll }
    public var kind: Kind
    public var x: Double?
    public var y: Double?
    public var text: String?
    public var keyCode: UInt16?
    public var clickCount: Int?
    public init(_ kind: Kind, x: Double? = nil, y: Double? = nil, text: String? = nil, keyCode: UInt16? = nil, clickCount: Int? = nil) {
        self.kind=kind; self.x=x; self.y=y; self.text=text; self.keyCode=keyCode; self.clickCount=clickCount
    }
    public var isValid: Bool {
        switch kind {
        case .move, .leftDown, .leftUp, .rightClick:
            guard let x, let y else { return false }; return x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y) && (1...2).contains(clickCount ?? 1)
        case .scroll:
            guard let x, let y else { return false }; return x.isFinite && y.isFinite && abs(x) <= 100 && abs(y) <= 100
        case .text: return text != nil && text!.utf8.count <= Self.maximumTextBytes
        case .keyDown, .keyUp: return keyCode != nil && keyCode! < 128
        case .releaseAll: return true
        }
    }
}
