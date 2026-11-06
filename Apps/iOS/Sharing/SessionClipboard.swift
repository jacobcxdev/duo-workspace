import Foundation
import Observation
import UIKit
import DuoCore

@MainActor @Observable
final class SessionClipboard {
    private(set) var isBusy = false
    private(set) var message: LocalizedStringResource?
    @ObservationIgnored var send: ((ClipboardRequest) -> Bool)?
    @ObservationIgnored private var pending: ClipboardRequest?
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private let writeLocal: (String) -> Void

    init(writeLocal: @escaping (String) -> Void = {
        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: $0]], options: [.localOnly: true])
    }) { self.writeLocal = writeLocal }

    func sendText(_ text: String) { request(.init(action: .write, text: text)) }
    func getText() { request(.init(action: .read)) }

    private func request(_ request: ClipboardRequest) {
        guard !isBusy else { return }
        guard request.isValid else { message = "Clipboard text must be 16 KB or smaller."; return }
        guard let send else { message = "Connect to your Mac to share text."; return }
        pending = request; isBusy = true; message = nil
        guard send(request) else { reset(); message = "Clipboard sharing is unavailable for this session."; return }
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            guard let self, self.pending?.id == request.id else { return }
            self.reset(); self.message = "Your Mac didn't respond. Try again."
        }
    }

    func receive(_ response: ClipboardResponse) {
        guard let request = pending, response.id == request.id else { return }
        guard response.isValid else { reset(); message = "Couldn't read the clipboard response."; return }
        reset()
        switch response.result {
        case .text:
            guard request.action == .read, let text = response.text else { message = "Unexpected clipboard response."; return }
            writeLocal(text); message = "Mac text copied to this device."
        case .copied:
            message = request.action == .write ? "Text copied to your Mac." : "Unexpected clipboard response."
        case .empty: message = "Your Mac's clipboard has no text."
        case .tooLarge: message = "Clipboard text must be 16 KB or smaller."
        case .denied: message = "This device needs control access to share the clipboard."
        case .failed: message = "Couldn't update the clipboard. Try again."
        }
    }

    func disconnect() { reset(); send = nil; message = nil }

    private func reset() {
        timeout?.cancel(); timeout = nil
        pending = nil; isBusy = false
    }
}
