import Foundation
import Testing
import DuoCore
@testable import DuoWorkspace

@MainActor
struct HostLibraryTests {
    @Test func editingAndForgettingPreserveIdentityUntilCredentialRemovalSucceeds() throws {
        let name = "HostLibrary.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let credentials = LibraryCredentials()
        let library = HostLibrary(defaults: defaults, credentials: credentials)
        let host = HostProfile(name: "Mac", address: "old.local")
        let pin = Data(repeating: 7, count: 32)
        try library.approve(host, pin: pin)
        credentials.rejectWrites = true
        try library.update(id: host.id, name: "Office", address: " NEW.local ", port: 47992, mode: .extend)
        #expect(credentials.pins[host.id] == pin)
        let reopened = HostLibrary(defaults: defaults, credentials: credentials)
        #expect(reopened.hosts.first?.id == host.id)
        #expect(reopened.hosts.first?.address == "new.local")
        #expect(reopened.hosts.first?.mode == .extend)
        #expect(throws: LibraryCredentials.Failure.self) { try library.remove(host) }
        #expect(library.hosts.count == 1)
        #expect(HostLibrary(defaults: defaults, credentials: credentials).hosts.count == 1)
        credentials.rejectWrites = false
        try library.remove(host)
        #expect(credentials.pins.isEmpty)
        #expect(HostLibrary(defaults: defaults, credentials: credentials).hosts.isEmpty)
    }

    @Test func failedApprovalNeverPublishesAnUnusableSavedMac() throws {
        let name = "HostLibraryFailure.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let credentials = LibraryCredentials()
        let library = HostLibrary(defaults: defaults, credentials: credentials)
        credentials.rejectWrites = true
        #expect(throws: LibraryCredentials.Failure.self) {
            try library.approve(HostProfile(name: "Mac", address: "mac.local"), pin: Data(repeating: 8, count: 32))
        }
        #expect(library.hosts.isEmpty)
        #expect(HostLibrary(defaults: defaults, credentials: credentials).hosts.isEmpty)
    }
}

@MainActor private final class LibraryCredentials: ClientCredentials {
    enum Failure: Error { case denied }
    var pins: [UUID: Data] = [:]
    var rejectWrites = false
    func identity() throws -> LocalIdentity { try LocalIdentity() }
    func host(_ id: UUID) throws -> HostCredential? { pins[id].map { HostCredential(publicKeyPin: $0) } }
    func save(_ credential: HostCredential, for id: UUID) throws {
        if rejectWrites { throw Failure.denied }
        pins[id] = credential.publicKeyPin
    }
    func remove(_ id: UUID) throws {
        if rejectWrites { throw Failure.denied }
        pins.removeValue(forKey: id)
    }
}
