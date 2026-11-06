import Foundation

protocol RevocationPersisting: Sendable {
    func load() throws -> Set<String>?
    func save(_ deniedIDs: Set<String>) throws
}
