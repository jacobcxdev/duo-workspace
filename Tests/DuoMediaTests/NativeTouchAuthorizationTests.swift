import Foundation
import Network
import Testing
import DuoCore
@testable import DuoHost

@MainActor
struct NativeTouchAuthorizationTests {
    @Test(arguments: [MessageKind.nativeTouchControl, .nativeTouchFrame])
    func unapprovedTLSClientCannotCreateOrDriveTouchscreen(_ kind: MessageKind) async throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        let access = DeviceAccessController(identity: server, registry: DeviceRegistry(hostPin: server.publicKeyPin), persist: { _ in })
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        let channel = SecureChannel(NWConnection(host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: try #require(host.listeningPort))!,
            using: try SecureParameters.client(identity: device, hostPin: server.publicKeyPin)))
        var closed = false
        channel.onReady = { [weak channel] in
            if kind == .nativeTouchControl {
                channel?.send(kind, object: NativeTouchControl(enabled: true))
            } else {
                channel?.send(kind, object: NativeTouchFrame(contextID: UUID(), contacts: [.init(id: 1, x: 0.5, y: 0.5)]))
            }
        }
        channel.onFailure = { _ in Task { @MainActor in closed = true } }
        channel.start(); defer { channel.cancel() }
        try await waitUntil { closed }
        #expect(host.receivedInputCount == 0)
        #expect(access.devices.isEmpty)
    }

}
