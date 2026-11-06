import Foundation
import Testing
import DuoCore
@testable import DuoHost

@MainActor struct FileAuthorizationTests {
    @Test func viewOnlyDeviceCannotOpenFilesOrReadClipboard() async throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        var registry = DeviceRegistry(hostPin: server.publicKeyPin)
        try registry.approve(pin: device.publicKeyPin, name: "View only")
        registry.setControl(false, id: device.id)
        let access = DeviceAccessController(identity: server, registry: registry, persist: { _ in })
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        let port = try #require(host.listeningPort)
        let primary = try AuthorizationTestClient(identity: device, host: server, port: port)
        defer { primary.channel.cancel() }
        try await waitUntil { primary.results.contains { $0.state == .approved } }
        primary.channel.send(.clipboardRequest, object: ClipboardRequest(action: .read))
        try await waitUntil { !primary.clipboardResults.isEmpty }
        #expect(primary.clipboardResults[0].result == .denied && primary.clipboardResults[0].text == nil)
        let files = try AuthorizationTestClient(identity: device, host: server, port: port, purpose: .files)
        defer { files.channel.cancel() }
        try await waitUntil { files.results.contains { $0.state == .denied } }
    }

    @Test func fileConnectionRequiresSameApprovedDeviceAndClosesWithWorkspace() async throws {
        let server = try LocalIdentity(), first = try LocalIdentity(), other = try LocalIdentity()
        var registry = DeviceRegistry(hostPin: server.publicKeyPin)
        try registry.approve(pin: first.publicKeyPin, name: "First")
        try registry.approve(pin: other.publicKeyPin, name: "Other")
        let access = DeviceAccessController(identity: server, registry: registry, persist: { _ in })
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        let port = try #require(host.listeningPort)
        let orphan = try AuthorizationTestClient(identity: first, host: server, port: port, purpose: .files)
        defer { orphan.channel.cancel() }
        try await waitUntil { orphan.results.contains { $0.state == .denied } }
        let primary = try AuthorizationTestClient(identity: first, host: server, port: port)
        defer { primary.channel.cancel() }
        try await waitUntil { primary.results.contains { $0.state == .approved } }
        let stranger = try AuthorizationTestClient(identity: other, host: server, port: port, purpose: .files)
        defer { stranger.channel.cancel() }
        try await waitUntil { stranger.results.contains { $0.state == .denied } }
        let files = try AuthorizationTestClient(identity: first, host: server, port: port, purpose: .files)
        defer { files.channel.cancel() }
        try await waitUntil { files.results.contains { $0.state == .approved } }
        primary.channel.cancel()
        try await waitUntil { files.failed }
        #expect(!files.kinds.contains(.videoFrame))
    }

}
