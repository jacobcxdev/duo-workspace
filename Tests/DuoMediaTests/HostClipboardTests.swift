import AppKit
import Testing
import DuoCore
@testable import DuoHost

@MainActor struct HostClipboardTests {
    @Test func permissionAndSizeFailuresPreserveClipboard() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Existing text", forType: .string)
        let service = HostClipboard(pasteboard: board)
        #expect(service.handle(.init(action: .read), allowed: false).result == .denied)
        #expect(service.handle(.init(action: .write, text: "Denied"), allowed: false).result == .denied)
        #expect(service.handle(.init(action: .write, text: String(repeating: "x", count: 20_000)), allowed: true).result == .denied)
        #expect(board.string(forType: .string) == "Existing text")
        let value = "Café 日本語 👩🏽‍💻\nSecond line"
        #expect(service.handle(.init(action: .write, text: value), allowed: true).result == .copied)
        #expect(service.handle(.init(action: .read), allowed: true).text == value)
    }
}
