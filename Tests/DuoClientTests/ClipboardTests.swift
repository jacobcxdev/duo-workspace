import Foundation
import Testing
import DuoCore
@testable import DuoWorkspace

@MainActor struct ClipboardTests {
    @Test func onlyRequestedReadsCanChangeLocalClipboard() {
        var copied: [String] = []
        var sent: [ClipboardRequest] = []
        let clipboard = SessionClipboard { copied.append($0) }
        clipboard.send = { sent.append($0); return true }
        clipboard.receive(.init(id: UUID(), result: .text, text: "Unsolicited"))
        #expect(copied.isEmpty)
        clipboard.getText()
        let read = sent[0]
        clipboard.receive(.init(id: UUID(), result: .text, text: "Wrong request"))
        #expect(clipboard.isBusy && copied.isEmpty)
        clipboard.receive(.init(id: read.id, result: .text, text: "Café 日本語"))
        #expect(copied == ["Café 日本語"] && !clipboard.isBusy)
        clipboard.sendText("Sent text")
        clipboard.receive(.init(id: sent[1].id, result: .text, text: "Wrong direction"))
        #expect(copied.count == 1)
        clipboard.getText()
        let abandoned = sent[2]
        clipboard.disconnect()
        clipboard.receive(.init(id: abandoned.id, result: .text, text: "Old session"))
        #expect(copied.count == 1)
    }
}
