import Foundation
import Network
import DuoCore

@MainActor final class AuthorizationTestClient {
    let channel: SecureChannel
    var results: [AuthorizationResult] = []
    var kinds: [MessageKind] = []
    var clipboardResults: [ClipboardResponse] = []
    var failed = false

    init(identity: LocalIdentity, host: LocalIdentity, port: UInt16, token: Data? = nil, purpose: ConnectionPurpose? = nil) throws {
        channel = SecureChannel(NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!,
            using: try SecureParameters.client(identity: identity, hostPin: host.publicKeyPin)))
        channel.onReady = { [weak channel] in channel?.send(.authorize, object: AuthorizationRequest(deviceName: "Test iPhone", invitationToken: token, purpose: purpose)) }
        channel.onPacketAsync = { @MainActor [weak self] packet in
            self?.kinds.append(packet.kind)
            if packet.kind == .authorization, let result = try? JSONDecoder().decode(AuthorizationResult.self, from: packet.payload) { self?.results.append(result) }
            if packet.kind == .clipboardResponse, let result = try? JSONDecoder().decode(ClipboardResponse.self, from: packet.payload) { self?.clipboardResults.append(result) }
        }
        channel.onFailure = { [weak self] _ in Task { @MainActor in self?.failed = true } }
        channel.start()
    }
}
