import Foundation

public struct ClipboardRequest: Codable, Equatable, Sendable {
    public enum Action: String, Codable, Sendable { case read, write }
    public static let maximumTextBytes = 16 * 1024
    public let id: UUID
    public let action: Action
    public let text: String?

    public init(id: UUID = UUID(), action: Action, text: String? = nil) {
        self.id = id; self.action = action; self.text = text
    }

    public var isValid: Bool {
        switch action {
        case .read: return text == nil
        case .write: return text.map { $0.utf8.count <= Self.maximumTextBytes } ?? false
        }
    }
}
