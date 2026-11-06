import Foundation
import Testing
@testable import DuoCore

struct SharingProtocolTests {
    @Test func addressOverridePreservesApprovalAndExpiry() throws {
        let original = try PairingInvitation(name: "Mac", address: "mac.local", hostPin: Data(repeating: 1, count: 32))
        let changed = try original.overridingAddress(" 100.101.102.103 ", port: 47992)
        #expect(changed.address == "100.101.102.103" && changed.port == 47992)
        #expect(changed.hostPin == original.hostPin && changed.token == original.token && changed.expiresAt == original.expiresAt)
        #expect(try PairingInvitation.parse(changed.link()) == changed)
        #expect(try original.overridingAddress("mac.example.ts.net").port == original.port)
        #expect(throws: IdentityError.self) { try original.overridingAddress("https://mac.local") }
        #expect(throws: IdentityError.self) { try original.overridingAddress("mac.local", port: 0) }
    }

    @Test func clipboardIsBoundedByUTF8AndHasUnambiguousActions() throws {
        #expect(!ClipboardRequest(action: .read, text: "unsolicited").isValid)
        #expect(!ClipboardRequest(action: .write).isValid)
        #expect(ClipboardRequest(action: .write, text: "").isValid)
        #expect(ClipboardRequest(action: .write, text: "Café 日本語 👩🏽‍💻\n").isValid)
        #expect(!ClipboardRequest(action: .write, text: String(repeating: "🖥", count: 5000)).isValid)
        let worst = ClipboardRequest(action: .write, text: String(repeating: "\u{0001}", count: ClipboardRequest.maximumTextBytes))
        #expect(worst.isValid)
        #expect(try JSONEncoder().encode(worst).count < 128 * 1024)
        #expect(!ClipboardResponse(id: UUID(), result: .copied, text: "unexpected").isValid)
    }
}
