import Foundation

public enum FileTransferError: String, Error, Codable, Sendable {
    case invalidFile, tooLarge, changed, storage, cancelled, timedOut, busy, integrity, unavailable, protocolViolation
}
