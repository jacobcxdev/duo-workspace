import AppKit
import DuoCore

@MainActor
struct HostClipboard {
    let pasteboard: NSPasteboard

    func handle(_ request: ClipboardRequest, allowed: Bool) -> ClipboardResponse {
        guard allowed, request.isValid else { return .init(id: request.id, result: .denied) }
        switch request.action {
        case .read:
            guard let text = pasteboard.string(forType: .string) else { return .init(id: request.id, result: .empty) }
            guard text.utf8.count <= ClipboardRequest.maximumTextBytes else { return .init(id: request.id, result: .tooLarge) }
            return .init(id: request.id, result: .text, text: text)
        case .write:
            guard let text = request.text else { return .init(id: request.id, result: .failed) }
            let item = NSPasteboardItem()
            guard item.setString(text, forType: .string) else { return .init(id: request.id, result: .failed) }
            pasteboard.clearContents()
            return .init(id: request.id, result: pasteboard.writeObjects([item]) ? .copied : .failed)
        }
    }
}
