import Foundation
import Network
import Testing
@testable import DuoCore

@MainActor
struct TransportReviewTests {
    @Test func slowPacketHandlerFinishesBeforeEOFIsReported() async throws {
        let host = try LocalIdentity(), device = try LocalIdentity()
        let listener = try NWListener(using: SecureParameters.server(identity: host, loopbackOnly: true), on: .any)
        var server: SecureChannel?
        var port: UInt16?
        var events: [String] = []
        var inFlight = 0
        var maximumInFlight = 0
        listener.newConnectionHandler = { connection in
            let channel = SecureChannel(connection)
            Task { @MainActor in server = channel }
            channel.onReady = { [weak channel] in
                guard let channel else { return }
                for value in 0..<4 { channel.send(.ping, payload: Data([UInt8(value)])) }
                channel.finish()
            }
            channel.start()
        }
        listener.stateUpdateHandler = { state in Task { @MainActor in if case .ready = state { port = listener.port?.rawValue } } }
        listener.start(queue: DispatchQueue(label: "Review.OrderedTransport"))
        defer { listener.cancel(); server?.cancel() }
        try await eventually { port != nil }
        let client = SecureChannel(NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: try #require(port))!,
            using: try SecureParameters.client(identity: device, hostPin: host.publicKeyPin)))
        defer { client.cancel() }
        client.onPacketAsync = { @MainActor packet in
            inFlight += 1; maximumInFlight = max(maximumInFlight, inFlight)
            try? await Task.sleep(for: .milliseconds(30))
            events.append("packet-\(packet.payload.first!)")
            inFlight -= 1
        }
        client.onFailure = { _ in Task { @MainActor in events.append("closed") } }
        client.start()
        try await eventually { events.count == 5 }
        #expect(events == ["packet-0", "packet-1", "packet-2", "packet-3", "closed"])
        #expect(maximumInFlight == 1)
    }

    @Test func encodingFailureEndsConnectionInsteadOfDroppingMessage() async throws {
        struct InvalidMessage: Encodable {
            func encode(to encoder: Encoder) throws {
                throw EncodingError.invalidValue("test", .init(codingPath: [], debugDescription: "Intentional failure"))
            }
        }
        let host = try LocalIdentity(), device = try LocalIdentity()
        let listener = try NWListener(using: SecureParameters.server(identity: host, loopbackOnly: true), on: .any)
        var server: SecureChannel?
        var port: UInt16?
        var receivedPacket = false
        var failure: String?
        listener.newConnectionHandler = { connection in
            let channel = SecureChannel(connection)
            Task { @MainActor in server = channel }
            channel.onPacketAsync = { @MainActor _ in receivedPacket = true }
            channel.start()
        }
        listener.stateUpdateHandler = { state in
            Task { @MainActor in if case .ready = state { port = listener.port?.rawValue } }
        }
        listener.start(queue: DispatchQueue(label: "Review.EncodingFailure"))
        defer { listener.cancel(); server?.cancel() }
        try await eventually { port != nil }
        let client = SecureChannel(NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: try #require(port))!,
            using: try SecureParameters.client(identity: device, hostPin: host.publicKeyPin)))
        defer { client.cancel() }
        client.onReady = { [weak client] in client?.send(.hello, object: InvalidMessage()) }
        client.onFailure = { message in Task { @MainActor in failure = message } }
        client.start()
        try await eventually { failure != nil }
        #expect(failure == "Invalid outgoing message")
        #expect(!receivedPacket)
    }

    @Test func exportersMatchPeersAndChangeAcrossConnections() async throws {
        let host = try LocalIdentity(), device = try LocalIdentity()
        let listener = try NWListener(using: SecureParameters.server(identity: host, loopbackOnly: true), on: .any)
        var serverChannels: [SecureChannel] = []
        var serverBindings: [UInt8: Data] = [:]
        var clientBindings: [UInt8: Data] = [:]
        var port: UInt16?
        listener.newConnectionHandler = { connection in
            let channel = SecureChannel(connection)
            channel.onPacketAsync = { @MainActor [weak channel] packet in
                guard let channel else { return }
                if let id = packet.payload.first { serverBindings[id] = channel.pairingSessionBinding() }
            }
            Task { @MainActor in serverChannels.append(channel) }
            channel.start()
        }
        listener.stateUpdateHandler = { state in Task { @MainActor in if case .ready = state { port = listener.port?.rawValue } } }
        listener.start(queue: DispatchQueue(label: "Review.Exporters"))
        defer { listener.cancel(); serverChannels.forEach { $0.cancel() } }
        try await eventually { port != nil }
        var clients: [SecureChannel] = []
        defer { clients.forEach { $0.cancel() } }
        for id: UInt8 in [0, 1] {
            let channel = SecureChannel(NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: try #require(port))!,
                using: try SecureParameters.client(identity: device, hostPin: host.publicKeyPin)))
            channel.onReadyAsync = { @MainActor [weak channel] in
                guard let channel else { return }
                clientBindings[id] = channel.pairingSessionBinding()
                channel.send(.ping, payload: Data([id]))
            }
            clients.append(channel); channel.start()
        }
        try await eventually { serverBindings.count == 2 && clientBindings.count == 2 }
        #expect(serverBindings[0] == clientBindings[0])
        #expect(serverBindings[1] == clientBindings[1])
        let bindingsDiffer = clientBindings[0] != clientBindings[1]
        #expect(bindingsDiffer)
        #expect(clientBindings[0]?.count == 32)
    }

    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<200 { if condition() { return }; try await Task.sleep(for: .milliseconds(30)) }
        throw Timeout()
    }
    private struct Timeout: Error {}
}
