import Foundation
import Network
import Testing
import DuoCore
@testable import DuoHost

@MainActor
struct MicrophoneAuthorizationTests {
    @Test(arguments: [MessageKind.microphoneControl, .microphoneFrame])
    func unapprovedPeerCannotEnableOrFeedMicrophone(_ kind: MessageKind) async throws {
        let server = try LocalIdentity(), device = try LocalIdentity()
        let access = DeviceAccessController(identity: server, registry: DeviceRegistry(hostPin: server.publicKeyPin), persist: { _ in })
        let host = HostController(access: access, port: 0, loopbackOnly: true)
        host.start(); defer { host.stop() }
        try await waitUntil { host.listeningPort != nil }
        let channel = SecureChannel(NWConnection(host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: try #require(host.listeningPort))!,
            using: try SecureParameters.client(identity: device, hostPin: server.publicKeyPin)))
        var ended = false
        channel.onReady = { [weak channel] in
            if kind == .microphoneControl {
                channel?.send(kind, object: MicrophoneControl(enabled: true, requestID: UUID()))
            } else {
                channel?.send(kind, object: MicrophoneFrame(stream: UUID(), index: 1, samples: Data(repeating: 0, count: 1920)))
            }
        }
        channel.onFailure = { _ in Task { @MainActor in ended = true } }
        channel.start(); defer { channel.cancel() }
        try await waitUntil { ended }
        #expect(!host.microphone.enabled && host.microphone.receivedFrames == 0)
    }

}
