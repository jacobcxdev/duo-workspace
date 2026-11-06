import Foundation
import Network
import Testing
import DuoCore
@testable import DuoWorkspace

@MainActor
struct ClientSecurityReviewTests {
    @Test func pairingAddressOverrideUsesNewRouteAndKeepsInvitedIdentity() async throws {
        let harness = try ReviewServer()
        defer { harness.stop() }
        harness.respond = { packet, channel in
            if packet.kind == .authorize {
                channel.send(.authorization, object: AuthorizationResult(.approved, message: "Approved"))
            } else if packet.kind == .hello {
                channel.send(.status, object: HostStatus(capabilities: Capabilities(canCapture: true, canControl: true, canCreateDisplay: true), message: "Connected"))
                RecoveryVideoFixture.send(to: channel)
            }
        }
        try await eventually { harness.port != nil }
        let invitation = try PairingInvitation(name: "Remote route", address: "unreachable.invalid", hostPin: harness.identity.publicKeyPin)
        let port: UInt16 = try #require(harness.port)
        let routed = try invitation.overridingAddress("127.0.0.1", port: port)
        let credentials = try ReviewCredentials()
        let suite = "AddressOverride.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SessionModel(defaults: defaults, credentials: credentials)
        defer { model.disconnect() }
        try model.preparePairing(routed, name: nil, mode: .control, replacing: nil)
        model.startPreparedPairing()
        try await eventually { model.canSendInput }
        let saved = try #require(model.library.hosts.first)
        #expect(saved.address == "127.0.0.1" && saved.port == routed.port)
        #expect(credentials.hosts[saved.id]?.publicKeyPin == invitation.hostPin)
    }

    @Test func captureRecoveryKeepsTheSessionAndPausesInputUntilVideoIsReady() async throws {
        let harness = try ReviewServer()
        defer { harness.stop() }
        harness.respond = { packet, channel in
            if packet.kind == .authorize {
                channel.send(.authorization, object: AuthorizationResult(.approved, message: "Approved", supportsAdaptiveDisplay: true))
            } else if packet.kind == .hello {
                channel.send(.status, object: HostStatus(capabilities: Capabilities(canCapture: true, canControl: true, canCreateDisplay: true), message: "Connected"))
                RecoveryVideoFixture.send(to: channel)
            }
        }
        try await eventually { harness.port != nil }
        let credentials = try ReviewCredentials()
        let profile = HostProfile(name: "Capture recovery", address: "127.0.0.1", port: try #require(harness.port))
        credentials.hosts[profile.id] = HostCredential(publicKeyPin: harness.identity.publicKeyPin)
        let name = "CaptureRecovery.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults, credentials: credentials)
        defer { model.disconnect() }
        model.connect(profile, mode: .extend)
        model.display.reportViewport(CGSize(width: 951, height: 635))
        try await eventually {
            if model.canSendInput { return true }
            if case .failed = model.state { return true }
            return false
        }
        try #require(model.canSendInput)
        let channel = try #require(harness.channels.last)
        model.input.modifier(.shift)
        model.input.composition = "にほん"
        try await eventually { harness.inputs.last?.kind == .keyDown }
        let capabilities = Capabilities(canCapture: true, canControl: true, canCreateDisplay: true)
        channel.send(.status, object: HostStatus(capabilities: capabilities, message: "Restoring screen capture…", captureRestarting: true))
        try await eventually { model.state == .waitingForFrame }
        #expect(model.hasVideo && model.canControl && !model.canSendInput)
        #expect(model.input.modifiers.isEmpty && model.active?.id == profile.id)
        #expect(model.input.composition == "にほん")
        try await eventually { harness.inputs.last?.kind == .releaseAll }
        let before = harness.inputs.count
        model.input.type("must not send while capture is unavailable")
        model.display.reportViewport(CGSize(width: 669, height: 917))
        RecoveryVideoFixture.send(to: channel)
        try await eventually { model.receivedFrames == 2 }
        try await Task.sleep(for: .milliseconds(450))
        #expect(model.state == .waitingForFrame && !model.canSendInput)
        #expect(harness.inputs.count == before)
        #expect(!harness.packets.contains(.resizeDesktop))
        channel.send(.status, object: HostStatus(capabilities: capabilities, message: "Connected", captureRestarting: false))
        try await eventually { model.canSendInput && harness.packets.contains(.resizeDesktop) }
        #expect(model.reconnectAttempt == 0 && !model.needsPairing)
        #expect(harness.packets.count(where: { $0 == .hello }) == 1)
        #expect(credentials.hosts[profile.id]?.publicKeyPin == harness.identity.publicKeyPin)
        let reset = model.input.keyboardResetID
        model.input.composition = "must cancel if control permission is lost"
        channel.send(.status, object: HostStatus(capabilities: Capabilities(canCapture: true, canControl: false, canCreateDisplay: true), message: "Restoring screen capture…", captureRestarting: true))
        try await eventually { model.state == .waitingForFrame }
        #expect(model.input.composition.isEmpty && model.input.keyboardResetID > reset)
        #expect(!model.canControl && !model.canSendInput)
        channel.send(.status, object: HostStatus(capabilities: Capabilities(canCapture: false, canControl: false, canCreateDisplay: true), message: "Permission required"))
        try await eventually { if case .failed = model.state { return true }; return false }
        #expect(!model.canSendInput && !model.hasVideo && !model.needsPairing)
        #expect(model.reconnectAttempt == 0)
        #expect(credentials.hosts[profile.id]?.publicKeyPin == harness.identity.publicKeyPin)
    }

    @Test func handshakeConnectionLossRetriesWithoutRequestingNewPairing() async throws {
        let harness = try HandshakeDropServer()
        defer { harness.stop() }
        try await eventually { harness.port != nil }
        let credentials = try ReviewCredentials()
        let pin = try LocalIdentity().publicKeyPin
        let profile = HostProfile(name: "Interrupted TLS", address: "127.0.0.1", port: try #require(harness.port))
        credentials.hosts[profile.id] = HostCredential(publicKeyPin: pin)
        let name = "DuoSecurityTest.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults, credentials: credentials)
        defer { model.disconnect() }
        model.connect(profile)
        try await eventually {
            if model.state == .reconnecting { return true }
            if case .failed = model.state { return true }
            return false
        }
        #expect(!model.needsPairing)
        try #require(model.state == .reconnecting)
        #expect(model.reconnectAttempt == 1)
        #expect(credentials.hosts[profile.id]?.publicKeyPin == pin)
        #expect(!model.canControl && !model.hasVideo)
        try await eventually { harness.connectionCount >= 2 }
        #expect(!model.needsPairing)
        #expect(credentials.hosts[profile.id]?.publicKeyPin == pin)
    }

    @Test func disablingReconnectCancelsThePendingRetry() async throws {
        let harness = try ReviewServer()
        try await eventually { harness.port != nil }
        let port = try #require(harness.port)
        harness.stop()
        let credentials = try ReviewCredentials()
        let profile = HostProfile(name: "Retry test", address: "127.0.0.1", port: port)
        credentials.hosts[profile.id] = HostCredential(publicKeyPin: harness.identity.publicKeyPin)
        let name = "DuoSecurityTest.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults, credentials: credentials)
        defer { model.disconnect() }
        model.connect(profile)
        try await eventually { model.state == .reconnecting }
        model.settings.automaticReconnect = false
        try await eventually { if case .failed = model.state { return true }; return false }
        #expect(model.reconnectAttempt == 1)
        #expect(!model.hasVideo)
    }
    @Test func wrongPinnedIdentityFailsWithoutAutomaticRetry() async throws {
        let harness = try ReviewServer()
        defer { harness.stop() }
        try await eventually { harness.port != nil }
        let credentials = try ReviewCredentials()
        let profile = HostProfile(name: "Wrong pin test", address: "127.0.0.1", port: try #require(harness.port))
        credentials.hosts[profile.id] = HostCredential(publicKeyPin: try LocalIdentity().publicKeyPin)
        let name = "DuoSecurityTest.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults, credentials: credentials)
        defer { model.disconnect() }
        model.connect(profile)
        try await eventually { if case .failed = model.state { return true }; return false }
        #expect(model.needsPairing)
        #expect(model.reconnectAttempt == 0)
        #expect(!model.canControl && !model.hasVideo)
        #expect(harness.packets.isEmpty)
    }

    @Test(arguments: [false, true]) func statusBeforeApprovalCannotEnableControls(captureRestarting: Bool) async throws {
        let harness = try ReviewServer()
        defer { harness.stop() }
        harness.respond = { packet, channel in
            if packet.kind == .authorize {
                channel.send(.status, object: HostStatus(capabilities: Capabilities(canCapture: true, canControl: true, canCreateDisplay: true), message: "Unapproved", captureRestarting: captureRestarting ? true : nil))
            }
        }
        try await eventually { harness.port != nil }
        let credentials = try ReviewCredentials()
        let profile = HostProfile(name: "Unapproved test", address: "127.0.0.1", port: try #require(harness.port))
        credentials.hosts[profile.id] = HostCredential(publicKeyPin: harness.identity.publicKeyPin)
        let name = "DuoSecurityTest.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults, credentials: credentials)
        defer { model.disconnect() }
        model.connect(profile)
        try await eventually { if case .failed = model.state { return true }; return false }
        #expect(!model.canControl && !model.hasVideo)
        #expect(!harness.packets.contains(.hello))
    }

    @Test func failedCredentialSaveDoesNotStartCaptureAndCanBeRetried() async throws {
        let harness = try ReviewServer()
        defer { harness.stop() }
        harness.respond = { packet, channel in
            if packet.kind == .authorize { channel.send(.authorization, object: AuthorizationResult(.approved, message: "Approved")) }
        }
        try await eventually { harness.port != nil }
        let credentials = try ReviewCredentials(); credentials.rejectSave = true
        let invitation = try PairingInvitation(name: "Persistence test", address: "127.0.0.1", port: #require(harness.port), hostPin: harness.identity.publicKeyPin)
        let name = "DuoSecurityTest.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults, credentials: credentials)
        defer { model.disconnect() }
        try model.pair(invitation)
        try await eventually { if case .failed = model.state { return true }; return false }
        #expect(model.library.hosts.isEmpty)
        #expect(model.message.contains("Keychain"))
        #expect(!harness.packets.contains(.hello))
        #expect(!model.hasVideo && !model.canControl)
        credentials.rejectSave = false
        model.reconnect()
        try await eventually { harness.packets.contains(.hello) }
        #expect(model.library.hosts.count == 1)
        #expect(credentials.hosts.count == 1)
    }

    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<200 { if condition() { return }; try await Task.sleep(for: .milliseconds(30)) }
        throw ReviewTimeout()
    }
    private struct ReviewTimeout: Error {}
}

@MainActor private final class ReviewCredentials: ClientCredentials {
    let localIdentity: LocalIdentity
    var hosts: [UUID: HostCredential] = [:]
    var rejectSave = false
    init() throws { localIdentity = try LocalIdentity() }
    func identity() throws -> LocalIdentity { localIdentity }
    func host(_ id: UUID) throws -> HostCredential? { hosts[id] }
    func save(_ credential: HostCredential, for id: UUID) throws {
        if rejectSave { throw IdentityError.keychain(-1) }
        hosts[id] = credential
    }
    func remove(_ id: UUID) throws { hosts.removeValue(forKey: id) }
}

@MainActor private final class ReviewServer {
    let identity: LocalIdentity
    let listener: NWListener
    var port: UInt16?
    var packets: [MessageKind] = []
    var inputs: [InputEvent] = []
    var channels: [SecureChannel] = []
    var respond: ((Packet, SecureChannel) -> Void)?

    init() throws {
        identity = try LocalIdentity()
        listener = try NWListener(using: SecureParameters.server(identity: identity, loopbackOnly: true), on: .any)
        listener.stateUpdateHandler = { [weak self] state in Task { @MainActor in
            if case .ready = state { self?.port = self?.listener.port?.rawValue }
        } }
        listener.newConnectionHandler = { [weak self] connection in Task { @MainActor in
            guard let self else { return }
            let channel = SecureChannel(connection)
            self.channels.append(channel)
            channel.onPacket = { [weak self, weak channel] packet in Task { @MainActor in
                guard let self, let channel else { return }
                self.packets.append(packet.kind)
                if packet.kind == .input, let event = try? JSONDecoder().decode(InputEvent.self, from: packet.payload) {
                    self.inputs.append(event)
                }
                if packet.kind == .ping { channel.send(.pong, payload: packet.payload) }
                else { self.respond?(packet, channel) }
            } }
            channel.start()
        } }
        listener.start(queue: DispatchQueue(label: "DuoSecurityReview.Server"))
    }
    func stop() { channels.forEach { $0.cancel() }; listener.cancel() }
}
