import Foundation

struct RevocationEnvelope: Codable {
    let payload: Data
    let signature: Data
}
