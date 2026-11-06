import Foundation

struct RevocationRecord: Codable {
    let version: Int
    let hostPin: Data
    let deniedIDs: [String]
}
