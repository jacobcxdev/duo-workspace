import SwiftUI
import Network
import Testing
import DuoCore
@testable import DuoWorkspace

@MainActor
struct AdaptiveClientTests {
    @Test func adaptiveHandshakeUsesViewportAndKeepsOneHello() async throws {
        let server = try AdaptiveTestServer(adaptive: true)
        defer { server.stop() }
        try await eventually { server.port != nil }
        let credentials = try AdaptiveTestCredentials(hostPin: server.identity.publicKeyPin)
        let name = "AdaptiveClient.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults, credentials: credentials)
        defer { model.disconnect() }
        model.connect(HostProfile(name: "Test", address: "127.0.0.1", port: try #require(server.port)), mode: .extend)
        model.display.reportViewport(CGSize(width: 951, height: 635))
        try await eventually { server.hellos.count == 1 }
        let hello = try #require(server.hellos.first)
        #expect(hello.version == 2 && hello.isValid)
        #expect(hello.supportsCaptureRecovery == true)
        #expect(hello.desktop == DesktopSize.viewport(width: 951, height: 635))
        model.display.reportViewport(CGSize(width: 669, height: 917))
        try await Task.sleep(for: .milliseconds(450))
        #expect(server.hellos.count == 1)
        #expect(server.resizes.isEmpty) // No resize before the initial video is ready.
    }

    @Test func legacyAndControlSessionsKeepTheExistingHandshake() async throws {
        for (adaptive, mode) in [(false, WorkspaceMode.extend), (true, WorkspaceMode.control)] {
            let server = try AdaptiveTestServer(adaptive: adaptive)
            defer { server.stop() }
            try await eventually { server.port != nil }
            let name = "AdaptiveLegacy.\(UUID())"
            let defaults = try #require(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            let model = SessionModel(defaults: defaults, credentials: try AdaptiveTestCredentials(hostPin: server.identity.publicKeyPin))
            defer { model.disconnect() }
            model.connect(HostProfile(name: "Test", address: "127.0.0.1", port: try #require(server.port)), mode: mode)
            model.display.reportViewport(CGSize(width: 669, height: 917))
            try await eventually { server.hellos.count == 1 }
            let hello = try #require(server.hellos.first)
            #expect(hello.version == 1 && hello.desktop == nil && hello.isValid)
            #expect(server.resizes.isEmpty)
        }
    }

    @Test func savedPortraitShapeAppliesToTheAdaptiveGreeting() async throws {
        let server = try AdaptiveTestServer(adaptive: true)
        defer { server.stop() }
        try await eventually { server.port != nil }
        let name = "AdaptiveShape.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults, credentials: try AdaptiveTestCredentials(hostPin: server.identity.publicKeyPin))
        defer { model.disconnect() }
        model.settings.desktopShape = .portrait3x4
        model.connect(HostProfile(name: "Test", address: "127.0.0.1", port: try #require(server.port)), mode: .extend)
        model.display.reportViewport(CGSize(width: 951, height: 669))
        try await eventually { server.hellos.count == 1 }
        let hello = try #require(server.hellos.first)
        #expect(hello.desktop == DesktopSize(width: 600, height: 800))
        #expect(hello.isValid)
    }

    @Test func retiredWorkspaceCannotReplaceTheNewPaneMeasurement() async throws {
        let server = try AdaptiveTestServer(adaptive: true)
        defer { server.stop() }
        try await eventually { server.port != nil }
        let name = "ViewportOwner.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults, credentials: try AdaptiveTestCredentials(hostPin: server.identity.publicKeyPin))
        defer { model.disconnect() }
        model.connect(HostProfile(name: "Test", address: "127.0.0.1", port: try #require(server.port)), mode: .extend)
        let old = WorkspaceViewportContext(rootSize: CGSize(width: 669, height: 951), layout: .canvas,
                                           keyboardMode: false, keyboardPresentation: .hidden)
        let current = WorkspaceViewportContext(rootSize: old.rootSize, layout: .tabletop,
                                               keyboardMode: false, keyboardPresentation: .hidden)
        model.display.selectViewport(old)
        model.display.reportViewport(old.rootSize, context: old)
        model.display.selectViewport(current)
        model.display.reportViewport(CGSize(width: 669, height: 455.6667), context: current)
        // A retiring subtree can remount after the new pane; its geometry is stale.
        model.display.reportViewport(old.rootSize, context: old)
        try await eventually { server.hellos.count == 1 }
        #expect(server.hellos.first?.desktop == DesktopSize(width: 800, height: 544))
    }

    @Test func fixedDesktopKeepsItsSizeAndRetainsTheLatestViewportForAutomatic() async throws {
        let server = try AdaptiveTestServer(adaptive: true)
        defer { server.stop() }
        try await eventually { server.port != nil }
        let name = "FixedRotation.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults, credentials: try AdaptiveTestCredentials(hostPin: server.identity.publicKeyPin))
        defer { model.disconnect() }
        model.settings.desktopShape = .landscape16x9
        model.connect(HostProfile(name: "Test", address: "127.0.0.1", port: try #require(server.port)), mode: .extend)
        model.display.reportViewport(CGSize(width: 951, height: 669))
        try await eventually { server.hellos.count == 1 }
        #expect(server.hellos.first?.desktop == DesktopSize(width: 960, height: 540))
        model.display.reportViewport(CGSize(width: 466, height: 678))
        model.settings.desktopShape = .automatic
        model.display.refreshDesktopShape()
        model.reconnect()
        try await eventually { server.hellos.count == 2 }
        #expect(server.hellos.last?.desktop == DesktopSize.viewport(width: 466, height: 678))
    }

    @Test func maximumDetailNegotiatesBeforeChoosingTheStreamDimensions() async throws {
        for supported in [false, true] {
            let server = try AdaptiveTestServer(adaptive: true, maximum: supported)
            defer { server.stop() }
            try await eventually { server.port != nil }
            let name = "MaximumDetail.\(UUID())"
            let defaults = try #require(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            let model = SessionModel(defaults: defaults, credentials: try AdaptiveTestCredentials(hostPin: server.identity.publicKeyPin))
            defer { model.disconnect() }
            model.settings.quality = .maximum
            model.settings.desktopShape = .landscape16x9
            model.settings.desktopSizing = .moreSpace
            model.connect(HostProfile(name: "Test", address: "127.0.0.1", port: try #require(server.port)), mode: .extend)
            model.display.reportViewport(CGSize(width: 951, height: 669))
            try await eventually { server.hellos.count == 1 }
            let hello = try #require(server.hellos.first)
            let effective: StreamQuality = supported ? .maximum : .sharp
            let expected = StreamDimensions.forDesktop(try #require(hello.desktop), quality: effective)
            #expect(hello.quality == effective && hello.width == expected.width && hello.height == expected.height)
            #expect(hello.isValid && model.display.qualityLimitedByHost == !supported)
            #expect(model.settings.quality == .maximum)
        }
    }

    @Test func displayMatchPersistsUntilAnExplicitUpdateAndIgnoresRetiredReports() async throws {
        let server = try AdaptiveTestServer(adaptive: true)
        defer { server.stop() }
        try await eventually { server.port != nil }
        let name = "DisplayMatch.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults, credentials: try AdaptiveTestCredentials(hostPin: server.identity.publicKeyPin))
        defer { model.disconnect() }
        model.settings.desktopShape = .landscape16x9; model.settings.desktopSizing = .matchDisplay
        model.connect(HostProfile(name: "Test", address: "127.0.0.1", port: try #require(server.port)), mode: .extend)
        let open = WorkspaceViewportContext(rootSize: CGSize(width: 951, height: 669), layout: .canvas,
                                            keyboardMode: false, keyboardPresentation: .hidden)
        let closed = WorkspaceViewportContext(rootSize: CGSize(width: 466, height: 678), layout: .canvas,
                                              keyboardMode: false, keyboardPresentation: .hidden)
        let inner = NativeDisplayInfo(pixels: DisplayPixelSize(width: 2007, height: 2853), pointWidth: 669, pointHeight: 951, nativeScale: 3)
        let cover = NativeDisplayInfo(pixels: DisplayPixelSize(width: 1398, height: 2034), pointWidth: 466, pointHeight: 678, nativeScale: 3)
        model.display.selectViewport(open)
        model.display.reportViewport(open.rootSize, display: inner, context: open)
        try await eventually { server.hellos.count == 1 }
        #expect(server.hellos.first?.desktop == DesktopSize(width: 1426, height: 802))
        model.display.selectViewport(closed)
        model.display.reportViewport(closed.rootSize, display: cover, context: closed)
        model.display.reportViewport(open.rootSize, display: inner, context: open)
        #expect(model.display.displayInfo == cover && model.settings.matchedDisplay == inner.pixels)
        model.settings.desktopShape = .landscape4x3; model.display.refreshDesktopShape()
        #expect(model.settings.matchedDisplay == inner.pixels)
        model.settings.desktopShape = .landscape16x9; model.display.refreshDesktopShape()
        let rotatedCover = WorkspaceViewportContext(rootSize: CGSize(width: 678, height: 466), layout: .canvas,
                                                    keyboardMode: false, keyboardPresentation: .hidden)
        model.display.selectViewport(rotatedCover)
        model.display.updateDisplayMatch()
        #expect(model.display.currentDisplayInfo == nil && model.settings.matchedDisplay == inner.pixels)
        model.display.reportViewport(rotatedCover.rootSize, display: cover, context: rotatedCover)
        #expect(model.settings.matchedDisplay == cover.pixels)
        model.reconnect()
        try await eventually { server.hellos.count == 2 }
        #expect(server.hellos.last?.desktop == DesktopSize(width: 1016, height: 572))
        #expect(AppSettings(defaults: defaults).matchedDisplay == cover.pixels)
    }

    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<150 { if condition() { return }; try await Task.sleep(for: .milliseconds(30)) }
        throw AdaptiveTimeout()
    }
    private struct AdaptiveTimeout: Error {}
}

@MainActor private final class AdaptiveTestCredentials: ClientCredentials {
    let local: LocalIdentity
    let pin: Data
    init(hostPin: Data) throws { pin = hostPin; local = try LocalIdentity() }
    func identity() throws -> LocalIdentity { local }
    func host(_ id: UUID) throws -> HostCredential? { HostCredential(publicKeyPin: pin) }
    func save(_ credential: HostCredential, for id: UUID) throws {}
    func remove(_ id: UUID) throws {}
}

@MainActor private final class AdaptiveTestServer {
    let identity: LocalIdentity
    let listener: NWListener
    var port: UInt16?
    var channels: [SecureChannel] = []
    var hellos: [ClientHello] = []
    var resizes: [DesktopResizeRequest] = []
    init(adaptive: Bool, maximum: Bool = false) throws {
        identity = try LocalIdentity()
        listener = try NWListener(using: SecureParameters.server(identity: identity, loopbackOnly: true), on: .any)
        listener.stateUpdateHandler = { [weak self] state in Task { @MainActor in
            if case .ready = state { self?.port = self?.listener.port?.rawValue }
        } }
        listener.newConnectionHandler = { [weak self] connection in Task { @MainActor in
            guard let self else { return }
            let channel = SecureChannel(connection); self.channels.append(channel)
            channel.onPacketAsync = { @MainActor [weak self, weak channel] packet in
                guard let self, let channel else { return }
                switch packet.kind {
                case .authorize: channel.send(.authorization, object: AuthorizationResult(.approved, message: "Approved", supportsAdaptiveDisplay: adaptive ? true : nil, supportsMaximumDetail: maximum ? true : nil))
                case .hello: if let hello = try? JSONDecoder().decode(ClientHello.self, from: packet.payload) { self.hellos.append(hello) }
                case .resizeDesktop: if let resize = try? JSONDecoder().decode(DesktopResizeRequest.self, from: packet.payload) { self.resizes.append(resize) }
                case .ping: channel.send(.pong, payload: packet.payload)
                default: break
                }
            }
            channel.start()
        } }
        listener.start(queue: DispatchQueue(label: "DuoAdaptiveTest"))
    }
    func stop() { channels.forEach { $0.cancel() }; listener.cancel() }
}
