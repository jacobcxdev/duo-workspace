import Foundation

public struct ClipboardResponse: Codable, Equatable, Sendable {
    public enum Result: String, Codable, Sendable { case copied, text, empty, tooLarge, denied, failed }
    public let id: UUID
    public let result: Result
    public let text: String?

    public init(id: UUID, result: Result, text: String? = nil) {
        self.id = id; self.result = result; self.text = text
    }

    public var isValid: Bool {
        if result == .text { return text.map { $0.utf8.count <= ClipboardRequest.maximumTextBytes } ?? false }
        return text == nil
    }
}
