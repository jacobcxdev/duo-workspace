import Foundation
import Testing
@testable import DuoCore

struct ConnectionPolicyTests {
    @Test func rejectsMalformedVideoBeforeDecoding() {
        #expect(H264AccessUnit(Data([0, 0, 0, 2, 0x65, 0x01]))?.isKeyframe == true)
        #expect(H264AccessUnit(Data([0, 0, 0, 2, 0x41, 0x01]))?.isKeyframe == false)
        #expect(H264AccessUnit(Data([0, 0, 0, 1, 0x65, 0])) == nil)
        #expect(H264AccessUnit(Data([0, 0, 0, 9, 0x65, 0x01])) == nil)
        #expect(H264AccessUnit(Data([0, 0, 0, 0, 0x65])) == nil)
        #expect(H264AccessUnit(Data([0, 0, 0, 1, 0xff])) == nil)
        #expect(H264AccessUnit(Data([0, 0, 1])) == nil)
    }
    @Test(arguments: ["mac.local", "192.168.1.20", "::1", "[fe80::1%en0]"])
    func acceptsHosts(_ address: String) { #expect(HostAddress.normalized(address) != nil) }

    @Test(arguments: ["", "https://mac.local", "mac.local:47991", "my mac", "user@host", "mac/path"])
    func rejectsAmbiguousAddresses(_ address: String) { #expect(HostAddress.normalized(address) == nil) }

    @Test func presetsAreValidAndLegacyHelloDecodes() throws {
        for quality in StreamQuality.allCases {
            #expect(ClientHello(mode: .extend, width: quality.width, height: quality.height, quality: quality).isValid)
        }
        #expect(!ClientHello(mode: .control, width: 3840, height: 2160, quality: .efficient).isValid)
        let legacy = Data(#"{"version":1,"mode":"control","width":1600,"height":1000}"#.utf8)
        let hello = try JSONDecoder().decode(ClientHello.self, from: legacy)
        #expect(hello.isValid && hello.supportsCaptureRecovery == nil)
        let status = HostStatus(capabilities: Capabilities(canCapture: true, canControl: true, canCreateDisplay: true), message: "Connected")
        let decoded = try JSONDecoder().decode(HostStatus.self, from: JSONEncoder().encode(status))
        #expect(decoded.captureRestarting == nil)
    }

    @Test func heartbeatIgnoresStaleAndUnsolicitedResponses() {
        var health = ConnectionHealth(now: 100)
        let first = health.ping(now: 102)
        let unsolicited = health.acknowledge(Data([0]), now: 103)
        #expect(!unsolicited)
        let valid = health.acknowledge(first, now: 102.02)
        #expect(valid)
        #expect(abs((health.roundTripMilliseconds ?? 0) - 20) < 0.001)
        let duplicate = health.acknowledge(first, now: 104)
        #expect(!duplicate)
        #expect(!health.isExpired(now: 112))
        #expect(health.isExpired(now: 113))
    }
}
