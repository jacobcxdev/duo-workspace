import XCTest
@testable import DuoCore

final class CoreTests:XCTestCase {
    func testFragmentedAndCoalescedPackets() throws {
        let a=try Packet(kind:.hello,sequence:1,payload:Data("hello".utf8)).encoded()
        let b=try Packet(kind:.ping,sequence:2,payload:Data()).encoded()
        var parser=PacketDecoder();var found=[Packet]()
        for byte in a { found += try parser.append(Data([byte])) }
        found += try parser.append(b)
        XCTAssertEqual(found.count,2);XCTAssertEqual(found[0].payload,Data("hello".utf8));XCTAssertEqual(found[1].sequence,2)
    }
    func testRejectsOversizedBeforeBodyArrives() throws {
        var h=try Packet(kind:.videoFrame,sequence:1,payload:Data()).encoded()
        h[4]=0x7f
        var p=PacketDecoder();XCTAssertThrowsError(try p.append(h)){XCTAssertEqual($0 as? WireError,.oversized)}
    }
    func testRejectsReplayAndUnknownVersion() throws {
        let a=try Packet(kind:.input,sequence:2,payload:Data()).encoded();var p=PacketDecoder();_ = try p.append(a)
        XCTAssertThrowsError(try p.append(a)){XCTAssertEqual($0 as? WireError,.replay)}
        var h=a;h[0]=9;var q=PacketDecoder();XCTAssertThrowsError(try q.append(h))
    }
    func testInputValidation() {
        XCTAssertFalse(InputEvent(.move,x:.nan,y:0).isValid)
        XCTAssertFalse(InputEvent(.move,x:2,y:0).isValid)
        XCTAssertFalse(InputEvent(.keyDown).isValid)
        XCTAssertFalse(InputEvent(.text,text:String(repeating:"x",count:9000)).isValid)
        XCTAssertTrue(InputEvent(.move,x:0.2,y:0.7).isValid)
        XCTAssertTrue(InputEvent(.text,text:"日本語 café").isValid)
    }

    func testSavedHostIgnoresObsoletePointerPreference() throws {
        let json = Data(#"{"id":"A6899923-287C-4453-B1AC-CCCFED2FBDF6","name":"Office Mac","address":"mac.local","port":47991,"mode":"extend","pointerMode":"obsolete-value"}"#.utf8)
        let profile = try JSONDecoder().decode(HostProfile.self, from: json)
        XCTAssertEqual(profile.name, "Office Mac")
        XCTAssertEqual(profile.address, "mac.local")
        XCTAssertEqual(profile.mode, .extend)
        let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any]
        XCTAssertNil(saved?["pointerMode"])
    }

    func testSavedHostContainsOnlyPublicPreferences() throws {
        let data = try JSONEncoder().encode(HostProfile(name: "Mac", address: "mac.local"))
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(fields.keys), ["id", "name", "address", "port", "mode"])
    }
}
