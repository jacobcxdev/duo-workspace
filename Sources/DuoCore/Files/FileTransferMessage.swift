import Foundation

public struct FileTransferMessage: Codable, Sendable {
    public enum Action: String, Codable, Sendable { case pick, offer, accept, chunk, ack, finish, complete, cancel, failed }
    public static let chunkBytes = 64 * 1024
    public let id: UUID
    public let action: Action
    public let offer: FileOffer?
    public let offset: UInt64?
    public let data: Data?
    public let failure: FileTransferError?
    public init(id: UUID, action: Action, offer: FileOffer? = nil, offset: UInt64? = nil, data: Data? = nil, failure: FileTransferError? = nil) {
        self.id = id; self.action = action; self.offer = offer; self.offset = offset; self.data = data; self.failure = failure
    }
    public var isValid: Bool {
        switch action {
        case .offer: return offer?.isValid == true && offset == nil && data == nil && failure == nil
        case .chunk: return offer == nil && offset != nil && data.map { !$0.isEmpty && $0.count <= Self.chunkBytes } == true && failure == nil
        case .ack: return offer == nil && offset != nil && data == nil && failure == nil
        case .finish: return offer == nil && offset == nil && data?.count == 32 && failure == nil
        case .failed: return offer == nil && offset == nil && data == nil && failure != nil
        default: return offer == nil && offset == nil && data == nil && failure == nil
        }
    }
}
