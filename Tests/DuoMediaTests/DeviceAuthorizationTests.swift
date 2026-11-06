import Foundation
import Network
import Testing
import DuoCore
@testable import DuoHost

@MainActor
struct DeviceAuthorizationTests {
    @Test func resizeWithoutAuthorizationIsRejected() async throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        let access = DeviceAccessController(identity: server, registry: DeviceRegistry(hostPin: server.publicKeyPin), persist: { _ in })
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        let connection = SecureChannel(NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: try #require(host.listeningPort))!,
            using: try SecureParameters.client(identity: device, hostPin: server.publicKeyPin)))
        var closed = false
        var video = false
        connection.onReady = { [weak connection] in
            connection?.send(.resizeDesktop, object: DesktopResizeRequest(revision: 1, desktop: DesktopSize(width: 900, height: 650)))
        }
        connection.onFailure = { _ in Task { @MainActor in closed = true } }
        connection.onPacketAsync = { @MainActor packet in if packet.kind == .videoFrame { video = true } }
        connection.start(); defer { connection.cancel() }
        try await waitUntil { closed }
        #expect(!video && host.receivedInputCount == 0)
    }

    @Test func resizeBeforeAnAuthorizedDesktopCannotCreateVideo() async throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        var registry = DeviceRegistry(hostPin: server.publicKeyPin)
        try registry.approve(pin: device.publicKeyPin, name: "Test")
        let access = DeviceAccessController(identity: server, registry: registry, persist: { _ in })
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        let client = try AuthorizationTestClient(identity: device, host: server, port: #require(host.listeningPort))
        defer { client.channel.cancel() }
        try await waitUntil { client.results.contains { $0.state == .approved } }
        client.channel.send(.resizeDesktop, object: DesktopResizeRequest(revision: 1, desktop: DesktopSize(width: 900, height: 650)))
        try await waitUntil { client.failed }
        #expect(!client.kinds.contains(.videoFrame))
        #expect(host.receivedInputCount == 0)
    }

    @Test func intentionalResizeHasItsOwnDeadline() throws {
        let identity = try LocalIdentity()
        let channel = SecureChannel(NWConnection(host: "127.0.0.1", port: 9, using: try SecureParameters.client(identity: identity, hostPin: identity.publicKeyPin)))
        let session = HostConnection(channel: channel)
        session.authorized = true; session.authorizedAt = 1; session.lastMessage = 100
        session.reconfiguringUntil = 108
        #expect(!session.isExpired(now: 102, captureStarted: false))
        #expect(session.isExpired(now: 109, captureStarted: false))
    }

    @Test func unauthenticatedConnectionsCannotExceedFourSlots() async throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        let access = DeviceAccessController(identity: server, registry: DeviceRegistry(hostPin: server.publicKeyPin), persist: { _ in })
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        let port = try #require(host.listeningPort)
        var ready = 0
        var rejected = false
        var clients: [SecureChannel] = []
        defer { clients.forEach { $0.cancel() } }
        for _ in 0..<4 {
            let channel = SecureChannel(NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!,
                using: try SecureParameters.client(identity: device, hostPin: server.publicKeyPin)))
            channel.onReadyAsync = { @MainActor in ready += 1 }
            clients.append(channel); channel.start()
        }
        try await waitUntil { ready == 4 }
        let extra = SecureChannel(NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!,
            using: try SecureParameters.client(identity: device, hostPin: server.publicKeyPin)))
        extra.onFailure = { _ in Task { @MainActor in rejected = true } }
        clients.append(extra); extra.start()
        try await waitUntil { rejected }
        #expect(access.pending.isEmpty)
        #expect(host.receivedInputCount == 0)
    }
    @Test func unknownIdentityWithoutInvitationIsDenied() async throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        let access = DeviceAccessController(identity: server, registry: DeviceRegistry(hostPin: server.publicKeyPin), persist: { _ in })
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        let client = try AuthorizationTestClient(identity: device, host: server, port: #require(host.listeningPort))
        defer { client.channel.cancel() }
        try await waitUntil { client.results.contains { $0.state == .denied } }
        #expect(access.pending.isEmpty)
        #expect(access.devices.isEmpty)
        #expect(!client.kinds.contains(.videoFrame))
    }

    @Test func disconnectedPairingRequestCannotBeApprovedLater() async throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        let access = DeviceAccessController(identity: server, registry: DeviceRegistry(hostPin: server.publicKeyPin), persist: { _ in })
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        access.makeInvitation(name: "Mac", address: "127.0.0.1")
        let client = try AuthorizationTestClient(identity: device, host: server, port: #require(host.listeningPort), token: #require(access.invitation?.token))
        try await waitUntil { !access.pending.isEmpty }
        let id = try #require(access.pending.first?.id)
        client.channel.cancel()
        try await waitUntil { access.pending.isEmpty }
        access.approve(id)
        #expect(access.devices.isEmpty)
    }

    @Test func approvalAndRevocationGateLiveTLSConnections() async throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        var persisted: Data?
        let access = DeviceAccessController(identity: server, registry: DeviceRegistry(hostPin: server.publicKeyPin)) {
            persisted = try JSONEncoder().encode($0)
        }
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        access.makeInvitation(name: "Test Mac", address: "127.0.0.1")
        let invitation = try #require(access.invitation)
        let client = try AuthorizationTestClient(identity: device, host: server, port: #require(host.listeningPort), token: invitation.token)
        defer { client.channel.cancel() }
        try await waitUntil { client.results.contains { $0.state == .pending } }
        #expect(access.devices.isEmpty)
        #expect(access.pending.first?.verificationCode == client.channel.pairingVerificationCode(hostPin: server.publicKeyPin, devicePin: device.publicKeyPin))
        #expect(access.invitation == nil)
        #expect(access.pending.first?.publicKeyPin == device.publicKeyPin)
        access.approve(try #require(access.pending.first?.id))
        try await waitUntil { client.results.contains { $0.state == .approved } }
        #expect(access.devices.first?.isApproved == true)
        let saved = try JSONDecoder().decode(DeviceRegistry.self, from: #require(persisted))
        #expect(saved.device(pin: device.publicKeyPin)?.isApproved == true)
        access.revoke(device.id)
        try await waitUntil { client.results.contains { $0.state == .revoked } }
        let revoked = try JSONDecoder().decode(DeviceRegistry.self, from: #require(persisted))
        #expect(revoked.device(pin: device.publicKeyPin)?.isApproved == false)
        let retry = try AuthorizationTestClient(identity: device, host: server, port: #require(host.listeningPort))
        defer { retry.channel.cancel() }
        try await waitUntil { retry.results.contains { $0.state == .revoked } }
        #expect(host.receivedInputCount == 0)
    }

    @Test func unapprovedDeviceCannotStartVideoOrInjectInput() async throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        let access = DeviceAccessController(identity: server, registry: DeviceRegistry(hostPin: server.publicKeyPin), persist: { _ in })
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        access.makeInvitation(name: "Test Mac", address: "127.0.0.1")
        let client = try AuthorizationTestClient(identity: device, host: server, port: #require(host.listeningPort), token: #require(access.invitation?.token))
        defer { client.channel.cancel() }
        try await waitUntil { !access.pending.isEmpty }
        client.channel.send(.input, object: InputEvent(.keyDown, keyCode: 0))
        client.channel.send(.hello, object: ClientHello(mode: .control, width: 1600, height: 1000))
        try await waitUntil { client.failed }
        #expect(host.receivedInputCount == 0)
        #expect(!client.kinds.contains(.videoFrame))
        #expect(access.devices.isEmpty)
        #expect(access.pending.isEmpty)
    }

    @Test func invitationCannotBeClaimedTwiceAndFailedPersistenceDoesNotApprove() throws {
        let server = try LocalIdentity(), first = try LocalIdentity(), second = try LocalIdentity()
        let access = DeviceAccessController(identity: server, registry: DeviceRegistry(hostPin: server.publicKeyPin)) { _ in throw IdentityError.keychain(-1) }
        access.makeInvitation(name: "Test Mac", address: "127.0.0.1")
        let token = try #require(access.invitation?.token)
        let id = UUID()
        #expect(access.authorize(pin: first.publicKeyPin, request: AuthorizationRequest(deviceName: "First", invitationToken: token), connectionID: id, verificationCode: "123456").state == .pending)
        #expect(access.authorize(pin: second.publicKeyPin, request: AuthorizationRequest(deviceName: "Second", invitationToken: token), connectionID: UUID(), verificationCode: "654321").state == .denied)
        access.approve(id)
        #expect(access.devices.isEmpty)
        #expect(access.pending.isEmpty)
    }

}
