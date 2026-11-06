import Foundation
import Network
import CryptoKit
import Testing
import DuoCore
@testable import DuoHost

@MainActor
struct RevocationReviewTests {
    @Test func trustStoreCannotHaveTwoWriters() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".artifacts/security-review/lease-tests/\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        var first: AccessStoreLease? = try AccessStoreLease.acquire(in: directory)
        #expect(first != nil)
        #expect(throws: IdentityError.self) { try AccessStoreLease.acquire(in: directory) }
        first = nil
        let replacement = try AccessStoreLease.acquire(in: directory)
        _ = replacement
    }
    @Test func keychainFailureStillRevokesLiveConnectionAndSurvivesReload() async throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        var registry = DeviceRegistry(hostPin: server.publicKeyPin)
        try registry.approve(pin: device.publicKeyPin, name: "Test device")
        let journal = ControlledRevocations()
        let access = DeviceAccessController(identity: server, registry: registry, revocations: journal) { _ in throw ReviewFailure.storage }
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        let client = try AuthorizationTestClient(identity: device, host: server, port: #require(host.listeningPort))
        defer { client.channel.cancel() }
        try await waitUntil { client.results.contains { $0.state == .approved } }
        access.revoke(device.id)
        try await waitUntil { client.results.contains { $0.state == .revoked } }
        #expect(access.approvedDevice(pin: device.publicKeyPin) == nil)
        #expect(access.devices.first?.isApproved == false)
        #expect(access.storageWarning != nil)
        let restored = DeviceAccessController(identity: server, registry: registry, revocations: journal,
            deniedIDs: try #require(try journal.load()), persist: { _ in })
        #expect(restored.authorize(pin: device.publicKeyPin, request: AuthorizationRequest(deviceName: "Test"),
            connectionID: UUID(), verificationCode: "123456").state == .revoked)
    }

    @Test func journalFailureKeepsDurableKeychainDenial() throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        var registry = DeviceRegistry(hostPin: server.publicKeyPin)
        try registry.approve(pin: device.publicKeyPin, name: "Test")
        let journal = ControlledRevocations(); journal.failWrites = true
        var saved: DeviceRegistry?
        var ended = false
        let access = DeviceAccessController(identity: server, registry: registry, revocations: journal) { saved = $0 }
        access.onRevoke = { _ in ended = true }
        access.revoke(device.id)
        #expect(ended)
        #expect(saved?.device(pin: device.publicKeyPin)?.isApproved == false)
        #expect(access.approvedDevice(pin: device.publicKeyPin) == nil)
    }

    @Test func bothStoresFailClosedAndRetryCannotRestoreAccess() throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        var registry = DeviceRegistry(hostPin: server.publicKeyPin)
        try registry.approve(pin: device.publicKeyPin, name: "Test")
        let journal = ControlledRevocations(); journal.failWrites = true
        var keychainFails = true
        var stopped = false
        let access = DeviceAccessController(identity: server, registry: registry, revocations: journal) { _ in
            if keychainFails { throw ReviewFailure.storage }
        }
        access.onStorageFailure = { stopped = true }
        access.revoke(device.id)
        #expect(stopped)
        #expect(!access.isReady)
        #expect(access.approvedDevice(pin: device.publicKeyPin) == nil)
        keychainFails = false; journal.failWrites = false
        access.retryStorage()
        #expect(access.isReady)
        #expect(access.storageWarning == nil)
        #expect(access.approvedDevice(pin: device.publicKeyPin) == nil)
        #expect(try journal.load()?.contains(device.id) == true)
    }

    @Test func interruptedApprovalCannotBecomeTrustedOnRestart() throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        let journal = ControlledRevocations(); journal.failOnWrite = 2
        var saved = DeviceRegistry(hostPin: server.publicKeyPin)
        let access = DeviceAccessController(identity: server, registry: saved, revocations: journal) { saved = $0 }
        access.makeInvitation(name: "Mac", address: "127.0.0.1")
        let id = UUID()
        let result = access.authorize(pin: device.publicKeyPin,
            request: AuthorizationRequest(deviceName: "Test", invitationToken: try #require(access.invitation?.token)),
            connectionID: id, verificationCode: "123456")
        #expect(result.state == .pending)
        access.approve(id)
        #expect(access.approvedDevice(pin: device.publicKeyPin) == nil)
        #expect(saved.device(pin: device.publicKeyPin)?.isApproved == false)
        let restored = DeviceAccessController(identity: server, registry: saved, revocations: journal,
            deniedIDs: try #require(try journal.load()), persist: { _ in })
        #expect(restored.approvedDevice(pin: device.publicKeyPin) == nil)
        #expect(restored.devices.first?.isApproved == false)
    }

    @Test func journalErrorAfterCommitRestoresDenialBeforeRestart() throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        let journal = ControlledRevocations(); journal.failAfterWrite = 2
        var saved = DeviceRegistry(hostPin: server.publicKeyPin)
        let access = DeviceAccessController(identity: server, registry: saved, revocations: journal) { saved = $0 }
        access.makeInvitation(name: "Mac", address: "127.0.0.1")
        let id = UUID()
        _ = access.authorize(pin: device.publicKeyPin,
            request: AuthorizationRequest(deviceName: "Test", invitationToken: try #require(access.invitation?.token)),
            connectionID: id, verificationCode: "123456")
        var decision: AuthorizationResult?
        access.onDecision = { _, result in decision = result }
        access.approve(id)
        #expect(decision?.state == .denied)
        #expect(saved.device(pin: device.publicKeyPin)?.isApproved == false)
        let prepared = try DeviceAccessController.prepareRegistry(saved, identity: server, revocations: journal) { saved = $0 }
        let restored = DeviceAccessController(identity: server, registry: prepared.0, revocations: journal,
            deniedIDs: prepared.1, persist: { _ in })
        #expect(restored.approvedDevice(pin: device.publicKeyPin) == nil)
    }

    @Test func keychainErrorAfterCommitRestoresDenialBeforeRestart() throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        let journal = ControlledRevocations()
        var saved = DeviceRegistry(hostPin: server.publicKeyPin)
        var writes = 0
        let access = DeviceAccessController(identity: server, registry: saved, revocations: journal) {
            saved = $0; writes += 1
            if writes == 1 { throw ReviewFailure.storage }
        }
        access.makeInvitation(name: "Mac", address: "127.0.0.1")
        let id = UUID()
        _ = access.authorize(pin: device.publicKeyPin,
            request: AuthorizationRequest(deviceName: "Test", invitationToken: try #require(access.invitation?.token)),
            connectionID: id, verificationCode: "123456")
        access.approve(id)
        #expect(access.approvedDevice(pin: device.publicKeyPin) == nil)
        #expect(saved.device(pin: device.publicKeyPin)?.isApproved != true)
        let prepared = try DeviceAccessController.prepareRegistry(saved, identity: server, revocations: journal) { saved = $0 }
        let restored = DeviceAccessController(identity: server, registry: prepared.0, revocations: journal,
            deniedIDs: prepared.1, persist: { _ in })
        #expect(restored.approvedDevice(pin: device.publicKeyPin) == nil)
    }

    @Test func signedJournalRejectsTamperingMissingRequiredFileAndWrongHost() throws {
        let key = P256.Signing.PrivateKey()
        let identity = try LocalIdentity(privateKey: key)
        let device = try LocalIdentity()
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".artifacts/security-review/journal-tests/\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("revocations.json")
        let journal = SignedRevocations(identity: identity, url: url)
        var registry = DeviceRegistry(hostPin: identity.publicKeyPin)
        try registry.approve(pin: device.publicKeyPin, name: "Test")
        var migrated: DeviceRegistry?
        _ = try DeviceAccessController.prepareRegistry(registry, identity: identity, revocations: journal) { migrated = $0 }
        #expect(migrated?.revocationJournalVersion == 1)
        try journal.save([device.id])
        let renewed = try LocalIdentity(privateKey: key, now: Date().addingTimeInterval(10))
        #expect(try SignedRevocations(identity: renewed, url: url).load() == [device.id])
        #expect(throws: IdentityError.self) { try SignedRevocations(identity: LocalIdentity(), url: url).load() }
        let valid = try Data(contentsOf: url)
        var envelope = try JSONDecoder().decode(RevocationEnvelope.self, from: valid)
        envelope = RevocationEnvelope(payload: envelope.payload + Data([0]), signature: envelope.signature)
        try JSONEncoder().encode(envelope).write(to: url)
        #expect(throws: IdentityError.self) { try journal.load() }
        try FileManager.default.removeItem(at: url)
        #expect(throws: IdentityError.self) {
            try DeviceAccessController.prepareRegistry(#require(migrated), identity: identity, revocations: journal) { _ in }
        }
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func pendingApprovalAndInvitationUseMonotonicDeadlines() throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        var tick = 0.0
        let access = DeviceAccessController(identity: server, registry: DeviceRegistry(hostPin: server.publicKeyPin), uptime: { tick }, persist: { _ in })
        access.makeInvitation(name: "Mac", address: "127.0.0.1")
        let expiredToken = try #require(access.invitation?.token)
        tick = 301
        #expect(access.authorize(pin: device.publicKeyPin, request: AuthorizationRequest(deviceName: "Test", invitationToken: expiredToken),
            connectionID: UUID(), verificationCode: "123456").state == .denied)
        access.makeInvitation(name: "Mac", address: "127.0.0.1")
        let id = UUID()
        _ = access.authorize(pin: device.publicKeyPin, request: AuthorizationRequest(deviceName: "Test", invitationToken: try #require(access.invitation?.token)),
            connectionID: id, verificationCode: "123456")
        tick += 61
        access.expirePendingRequests()
        access.approve(id)
        #expect(access.pending.isEmpty)
        #expect(access.devices.isEmpty)
    }

    @Test func expiringOneApprovalDoesNotExpireANewerRequest() throws {
        let server = try LocalIdentity(), first = try LocalIdentity(), second = try LocalIdentity()
        var tick = 0.0
        let access = DeviceAccessController(identity: server, registry: DeviceRegistry(hostPin: server.publicKeyPin),
            uptime: { tick }, persist: { _ in })
        func request(_ identity: LocalIdentity) throws -> UUID {
            access.makeInvitation(name: "Mac", address: "127.0.0.1")
            let id = UUID()
            let result = access.authorize(pin: identity.publicKeyPin,
                request: AuthorizationRequest(deviceName: "Test", invitationToken: try #require(access.invitation?.token)),
                connectionID: id, verificationCode: "123456")
            #expect(result.state == .pending)
            return id
        }
        _ = try request(first)
        tick = 30
        let newer = try request(second)
        tick = 61
        access.expirePendingRequests()
        #expect(access.pending.map(\.id) == [newer])
        access.approve(newer)
        #expect(access.approvedDevice(pin: first.publicKeyPin) == nil)
        #expect(access.approvedDevice(pin: second.publicKeyPin) != nil)
    }

    @Test func lateApprovalGetsFreshHandshakeDeadline() throws {
        let identity = try LocalIdentity()
        let transport = SecureChannel(NWConnection(host: "127.0.0.1", port: 9,
            using: try SecureParameters.client(identity: identity, hostPin: identity.publicKeyPin)))
        let session = HostConnection(channel: transport)
        session.authorized = true
        session.authorizedAt = session.createdAt + 50
        session.lastMessage = session.createdAt + 50
        #expect(!session.isExpired(now: session.createdAt + 51, captureStarted: false))
        session.lastMessage = session.createdAt + 70
        #expect(session.isExpired(now: session.createdAt + 71, captureStarted: false))
        #expect(!session.isExpired(now: session.createdAt + 71, captureStarted: true))
    }

}

private enum ReviewFailure: Error { case storage }
private final class ControlledRevocations: RevocationPersisting, @unchecked Sendable {
    var values: Set<String>?
    var failWrites = false
    var failOnWrite: Int?
    var failAfterWrite: Int?
    private var writes = 0
    func load() throws -> Set<String>? { values }
    func save(_ deniedIDs: Set<String>) throws {
        writes += 1
        if failWrites || failOnWrite == writes { throw ReviewFailure.storage }
        values = deniedIDs
        if failAfterWrite == writes { throw ReviewFailure.storage }
    }
}
