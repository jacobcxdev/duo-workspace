import Foundation
import Observation

/// One bounded, acknowledged transfer per connection. Only local UI chooses paths.
@MainActor @Observable
public final class FileTransferEngine {
    public private(set) var state = FileTransferState.idle
    public private(set) var offer: FileOffer?
    public private(set) var transferred: UInt64 = 0
    public private(set) var receivedURL: URL?
    public private(set) var failure: FileTransferError?
    @ObservationIgnored public var send: ((FileTransferMessage) -> Void)?
    @ObservationIgnored public var onOffer: (() -> Void)?
    @ObservationIgnored private var id: UUID?
    @ObservationIgnored private var source: TransferSource?
    @ObservationIgnored private var destination: TransferDestination?
    @ObservationIgnored private var expectedAck: UInt64?
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private var lastChunkSent: TimeInterval = 0

    public init() {}

    public func sendFile(_ url: URL, id: UUID = UUID()) async {
        guard !state.isBusy, send != nil else { return }
        start(id: id); state = .preparing
        do {
            let opened = try await Task.detached(priority: .utility) { try TransferSource(url: url) }.value
            guard self.id == id else { await opened.close(); return }
            source = opened; offer = opened.offer; state = .offering
            send?(.init(id: id, action: .offer, offer: opened.offer))
            armTimeout(seconds: 120)
        } catch { fail(error, id: id) }
    }

    public func accept(into directory: URL) async {
        guard state == .awaitingAcceptance, let id, let offer else { return }
        state = .preparing
        do {
            let opened = try await Task.detached(priority: .utility) { try TransferDestination(offer: offer, directory: directory) }.value
            guard self.id == id else { await opened.cancel(); return }
            destination = opened; state = .receiving
            send?(.init(id: id, action: .accept)); armTimeout()
        } catch { fail(error, id: id) }
    }

    public func receive(_ message: FileTransferMessage) async throws {
        guard message.isValid else { throw FileTransferError.protocolViolation }
        if message.action == .offer {
            guard !state.isBusy else { send?(.init(id: message.id, action: .failed, failure: .busy)); return }
            start(id: message.id); offer = message.offer; state = .awaitingAcceptance
            armTimeout(seconds: 120); onOffer?(); return
        }
        guard message.id == id else { return } // A cancelled transfer can still have in-flight packets.
        armTimeout()
        do {
            switch message.action {
            case .accept:
                guard state == .offering, source != nil else { throw FileTransferError.protocolViolation }
                state = .sending; try await sendNext(id: message.id)
            case .chunk:
                guard state == .receiving, let destination, let data = message.data, let position = message.offset else { throw FileTransferError.protocolViolation }
                let count = try await destination.append(data, at: position)
                guard id == message.id else { return }
                transferred = count
                send?(.init(id: message.id, action: .ack, offset: count))
            case .ack:
                guard state == .sending, let expectedAck, expectedAck == message.offset else { throw FileTransferError.protocolViolation }
                transferred = expectedAck; self.expectedAck = nil
                try await sendNext(id: message.id)
            case .finish:
                guard state == .receiving, let destination, let digest = message.data else { throw FileTransferError.protocolViolation }
                state = .finishing
                let url = try await destination.finish(digest: digest)
                guard id == message.id else { return }
                self.destination = nil; receivedURL = url; state = .completed; timeout?.cancel()
                send?(.init(id: message.id, action: .complete))
            case .complete:
                guard state == .finishing, destination == nil else { throw FileTransferError.protocolViolation }
                state = .completed; timeout?.cancel(); source = nil
            case .cancel: fail(FileTransferError.cancelled, id: message.id, notify: false)
            case .failed: fail(message.failure ?? .unavailable, id: message.id, notify: false)
            default: throw FileTransferError.protocolViolation
            }
        } catch { fail(error, id: message.id) }
    }

    public func cancel() {
        guard let id, state.isBusy else { return }
        send?(.init(id: id, action: .cancel))
        fail(FileTransferError.cancelled, id: id, notify: false)
    }

    public func disconnect() { cancel(); send = nil }

    private func sendNext(id: UUID) async throws {
        guard self.id == id, let source, let offer, state == .sending else { return }
        if transferred == offer.size {
            let digest = try await source.finish()
            guard self.id == id else { return }
            state = .finishing
            send?(.init(id: id, action: .finish, data: digest))
        } else {
            // Stay below the transport's packet budget even on loopback. This
            // also leaves main-actor time for interactive desktop controls.
            let delay = 0.008 - (ProcessInfo.processInfo.systemUptime - lastChunkSent)
            if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
            guard self.id == id else { return }
            let data = try await source.read()
            guard self.id == id else { return }
            expectedAck = transferred + UInt64(data.count)
            lastChunkSent = ProcessInfo.processInfo.systemUptime
            send?(.init(id: id, action: .chunk, offset: transferred, data: data))
        }
    }

    private func start(id: UUID) {
        self.id = id; offer = nil; transferred = 0; receivedURL = nil; failure = nil; expectedAck = nil
        lastChunkSent = 0
    }

    private func fail(_ error: Error, id: UUID, notify: Bool = true) {
        guard self.id == id else { return }
        let failure = error as? FileTransferError ?? .storage
        if notify { send?(.init(id: id, action: .failed, failure: failure)) }
        self.failure = failure; state = .failed; self.id = nil; timeout?.cancel()
        let source = source, destination = destination
        self.source = nil; self.destination = nil; expectedAck = nil
        Task { await source?.close(); await destination?.cancel() }
    }

    private func armTimeout(seconds: Int = 45) {
        timeout?.cancel()
        let current = id
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard let self, let current, self.id == current, self.state.isBusy else { return }
            self.fail(FileTransferError.timedOut, id: current)
        }
    }
}
