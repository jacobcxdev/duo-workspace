import Foundation
import DuoCore

@MainActor
protocol ClientCredentials {
    func identity() throws -> LocalIdentity
    func host(_ id: UUID) throws -> HostCredential?
    func save(_ credential: HostCredential, for id: UUID) throws
    func remove(_ id: UUID) throws
}

struct KeychainClientCredentials: ClientCredentials {
    func identity() throws -> LocalIdentity { try LocalIdentity.loadOrCreate(account: "client-identity-v2") }
    func host(_ id: UUID) throws -> HostCredential? { try HostCredential.load(hostID: id) }
    func save(_ credential: HostCredential, for id: UUID) throws { try credential.save(hostID: id) }
    func remove(_ id: UUID) throws {
        try HostCredential.delete(hostID: id)
    }
}
