import Foundation
import CryptoKit

/// Minimal X.509 encoding only. Signing and all verification use CryptoKit/Security.
/// Identities are self-signed; trust comes from the out-of-band public-key pin.
enum CertificateDER {
    static func certificate(key: P256.Signing.PrivateKey, now: Date) throws -> Data {
        let algorithm = sequence([oid([1, 2, 840, 10045, 4, 3, 2])])
        let name = sequence([tag(0x31, sequence([oid([2, 5, 4, 3]), tag(0x0c, Data("Duo Workspace".utf8))]))])
        let publicKey = sequence([
            sequence([oid([1, 2, 840, 10045, 2, 1]), oid([1, 2, 840, 10045, 3, 1, 7])]),
            tag(0x03, Data([0]) + key.publicKey.x963Representation)
        ])
        let extensions = tag(0xa3, sequence([
            sequence([oid([2, 5, 29, 19]), tag(0x01, Data([0xff])), tag(0x04, sequence([]))]),
            sequence([oid([2, 5, 29, 15]), tag(0x01, Data([0xff])), tag(0x04, tag(0x03, Data([7, 0x80])))]),
            sequence([oid([2, 5, 29, 37]), tag(0x04, sequence([oid([1, 3, 6, 1, 5, 5, 7, 3, 1]), oid([1, 3, 6, 1, 5, 5, 7, 3, 2])]))]),
            sequence([oid([2, 5, 29, 17]), tag(0x04, sequence([tag(0x82, Data("duoworkspace.local".utf8))]))])
        ]))
        let serial = try SecureRandom.bytes(count: 16)
        let tbs = sequence([
            tag(0xa0, integer(Data([2]))), integer(Data(serial)), algorithm, name,
            sequence([time(now.addingTimeInterval(-300)), time(now.addingTimeInterval(365 * 86_400))]),
            name, publicKey, extensions
        ])
        let signature = try key.signature(for: tbs).derRepresentation
        return sequence([tbs, algorithm, tag(0x03, Data([0]) + signature)])
    }

    private static func time(_ date: Date) -> Data {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyMMddHHmmss'Z'"
        return tag(0x17, Data(formatter.string(from: date).utf8))
    }

    private static func integer(_ value: Data) -> Data {
        var bytes = Data(value.drop(while: { $0 == 0 }))
        if bytes.isEmpty { bytes = Data([0]) }
        if bytes.first! & 0x80 != 0 { bytes.insert(0, at: bytes.startIndex) }
        return tag(0x02, bytes)
    }

    private static func sequence(_ parts: [Data]) -> Data { tag(0x30, parts.reduce(into: Data()) { $0.append($1) }) }

    private static func tag(_ tag: UInt8, _ value: Data) -> Data {
        var result = Data([tag])
        if value.count < 128 { result.append(UInt8(value.count)) }
        else {
            var length = value.count
            var octets: [UInt8] = []
            repeat { octets.insert(UInt8(length & 0xff), at: 0); length >>= 8 } while length > 0
            result.append(0x80 | UInt8(octets.count)); result.append(contentsOf: octets)
        }
        result.append(value)
        return result
    }

    private static func oid(_ arcs: [UInt64]) -> Data {
        var value = Data([UInt8(arcs[0] * 40 + arcs[1])])
        for arc in arcs.dropFirst(2) {
            var n = arc
            var bytes = [UInt8(n & 0x7f)]
            n >>= 7
            while n > 0 { bytes.insert(UInt8(n & 0x7f) | 0x80, at: 0); n >>= 7 }
            value.append(contentsOf: bytes)
        }
        return tag(0x06, value)
    }
}
