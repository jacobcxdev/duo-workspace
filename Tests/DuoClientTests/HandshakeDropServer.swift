import Foundation
import Network

/// Accept TCP, then close without completing TLS, as a dropped relay does.
@MainActor
final class HandshakeDropServer {
    private let listener: NWListener
    private var connections: [NWConnection] = []
    private(set) var port: UInt16?
    private(set) var connectionCount = 0

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters, on: .any)
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .ready = state { self?.port = self?.listener.port?.rawValue }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                guard let self else { connection.cancel(); return }
                self.connections.append(connection)
                self.connectionCount += 1
                connection.stateUpdateHandler = { [weak connection] state in
                    guard case .ready = state, let connection else { return }
                    // Read ClientHello, then send TCP EOF without TLS close_notify.
                    // This exercises a TLS-domain closure, not only ECONNRESET.
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak connection] _, _, _, _ in
                        connection?.send(content: nil, contentContext: .finalMessage, isComplete: true,
                                         completion: .contentProcessed { _ in })
                    }
                }
                connection.start(queue: DispatchQueue(label: "DuoTest.HandshakeDrop"))
            }
        }
        listener.start(queue: DispatchQueue(label: "DuoTest.HandshakeDropListener"))
    }

    func stop() {
        listener.cancel()
        connections.forEach { $0.cancel() }
    }
}
