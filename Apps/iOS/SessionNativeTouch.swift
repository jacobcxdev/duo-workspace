import Foundation
import Observation
import DuoCore

@MainActor @Observable
final class SessionNativeTouch {
    var supported = false
    private(set) var status = NativeTouchStatus(.off)
    private(set) var enabled = false
    private(set) var cancellationID: UInt64 = 0
    var isReady: Bool { enabled && status.state == .ready && status.contextID != nil }
    @ObservationIgnored var sendControl: ((NativeTouchControl) -> Bool)?
    @ObservationIgnored var sendFrame: ((NativeTouchFrame) -> Void)?
    @ObservationIgnored var gestureEnded: (() -> Void)?
    @ObservationIgnored var positionChanged: ((NativeTouchContact) -> Void)?
    @ObservationIgnored private var contacts: [NativeTouchContact] = []
    @ObservationIgnored private var heartbeat: Task<Void, Never>?

    func setEnabled(_ value: Bool) {
        let next = value && supported
        guard next != enabled else { return }
        cancelContacts()
        heartbeat?.cancel(); heartbeat = nil
        enabled = next
        status = NativeTouchStatus(next ? .starting : .off)
        if sendControl?(NativeTouchControl(enabled: next)) != true, next {
            enabled = false
            status = NativeTouchStatus(.unavailable, failure: .device)
        }
    }

    func receive(_ value: NativeTouchStatus) {
        guard enabled, value.isValid else { return }
        if status.contextID != value.contextID || value.state != .ready {
            let hadContacts = !contacts.isEmpty
            contacts = []; heartbeat?.cancel(); heartbeat = nil
            cancellationID &+= 1
            if hadContacts { gestureEnded?() }
        }
        status = value
        guard isReady, heartbeat == nil else { return }
        emit()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                guard let self, self.isReady else { return }
                self.emit()
            }
        }
    }

    func updateContacts(_ value: [NativeTouchContact]) {
        guard isReady, let context = status.contextID,
              NativeTouchFrame(contextID: context, contacts: value).isValid else { return }
        let ended = !contacts.isEmpty && value.isEmpty
        if let first = value.first { positionChanged?(first) }
        contacts = value; emit()
        if ended { gestureEnded?() }
    }

    func cancelContacts() {
        let hadContacts = !contacts.isEmpty
        contacts = []
        if hadContacts { cancellationID &+= 1 }
        emit()
        if hadContacts { gestureEnded?() }
    }

    func disconnect() {
        cancelContacts(); heartbeat?.cancel(); heartbeat = nil
        supported = false; enabled = false; status = NativeTouchStatus(.off)
    }

    private func emit() {
        guard isReady, let context = status.contextID else { return }
        sendFrame?(NativeTouchFrame(contextID: context, contacts: contacts))
    }
}
