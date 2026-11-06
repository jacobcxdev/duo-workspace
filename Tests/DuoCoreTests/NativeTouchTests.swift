import Foundation
import Testing
@testable import DuoCore

struct NativeTouchTests {
    @Test func validatesBoundedDistinctContacts() throws {
        let context = UUID()
        let contacts = (1...5).map { NativeTouchContact(id: UInt8($0), x: Double($0) / 5, y: 0.5) }
        let frame = NativeTouchFrame(contextID: context, contacts: contacts)
        #expect(frame.isValid)
        #expect(try JSONDecoder().decode(NativeTouchFrame.self, from: JSONEncoder().encode(frame)) == frame)
        #expect(NativeTouchFrame(contextID: context, contacts: []).isValid)
        #expect(!NativeTouchFrame(contextID: context, contacts: contacts + [.init(id: 6, x: 0.5, y: 0.5)]).isValid)
        #expect(!NativeTouchFrame(contextID: context, contacts: [contacts[0], contacts[0]]).isValid)
        #expect(!NativeTouchContact(id: 0, x: 0.5, y: 0.5).isValid)
        #expect(!NativeTouchContact(id: 128, x: 0.5, y: 0.5).isValid)
        #expect(!NativeTouchContact(id: 1, x: .nan, y: 0.5).isValid)
        #expect(!NativeTouchContact(id: 1, x: 0.5, y: .infinity).isValid)
        #expect(!NativeTouchContact(id: 1, x: -0.001, y: 0.5).isValid)
        #expect(!NativeTouchContact(id: 1, x: 0.5, y: 1.001).isValid)
    }

    @Test func readyStatusRequiresContextAndNoFailure() {
        #expect(NativeTouchStatus(.ready, contextID: UUID()).isValid)
        #expect(!NativeTouchStatus(.ready).isValid)
        #expect(!NativeTouchStatus(.paused, contextID: UUID()).isValid)
        #expect(!NativeTouchStatus(.ready, contextID: UUID(), failure: .device).isValid)
    }

    @Test func oldHostsDoNotAdvertiseNativeTouch() throws {
        let old = Data(#"{"state":"approved","message":"Connected"}"#.utf8)
        #expect(try JSONDecoder().decode(AuthorizationResult.self, from: old).supportsNativeTouch == nil)
    }
}
