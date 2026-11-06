import Foundation
import Testing
@testable import DuoHost

struct NativeTouchDescriptorTests {
    @Test func fiveContactReportKeepsItsHIDLayout() {
        let descriptor = Array(NativeTouchDescriptor.descriptor())
        var offset = 0, reportID: UInt8 = 0, size = 0, count = 0
        var inputBits: [UInt8: Int] = [:], featureBits: [UInt8: Int] = [:]
        while offset < descriptor.count {
            let prefix = descriptor[offset]
            let length = [0, 1, 2, 4][Int(prefix & 3)]
            let payload = descriptor[(offset + 1)..<(offset + 1 + length)]
            let value = payload.enumerated().reduce(0) { $0 | Int($1.element) << ($1.offset * 8) }
            switch prefix & 0xfc {
            case 0x74: size = value
            case 0x94: count = value
            case 0x84: reportID = UInt8(value)
            case 0x80: inputBits[reportID, default: 0] += size * count
            case 0xb0: featureBits[reportID, default: 0] += size * count
            default: break
            }
            offset += 1 + length
        }
        #expect(inputBits == [1: 248])
        #expect(featureBits == [2: 8])
        #expect(Array(descriptor.suffix(11)) == [0x85, 0x02, 0x09, 0x55, 0x75, 0x08, 0x95, 0x01, 0xB1, 0x02, 0xC0])
    }
}
