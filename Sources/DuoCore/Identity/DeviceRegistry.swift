import Foundation

public struct DeviceRegistry: Codable, Sendable {
    public let hostPin: Data
    public private(set) var devices: [PairedDevice] = []
    public private(set) var revocationJournalVersion: Int?
    public init(hostPin: Data) { self.hostPin = hostPin }
    public func device(pin: Data) -> PairedDevice? { devices.first { LocalIdentity.matches($0.publicKeyPin, pin) } }
    public mutating func approve(pin: Data, name: String, now: Date = Date()) throws {
        guard pin.count == 32, DeviceDisplayName.isValid(name) else { throw IdentityError.invalidIdentity }
        if let index = devices.firstIndex(where: { LocalIdentity.matches($0.publicKeyPin, pin) }) {
            devices[index].revokedAt = nil; devices[index].name = name
        } else {
            guard devices.count < 64 else { throw IdentityError.invalidIdentity }
            devices.append(PairedDevice(publicKeyPin: pin, name: name, now: now))
        }
    }
    public mutating func revoke(id: String, now: Date = Date()) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        devices[index].revokedAt = now
    }
    public mutating func setControl(_ allowed: Bool, id: String) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        devices[index].allowsControl = allowed
    }
    public mutating func requireRevocationJournal() { revocationJournalVersion = 1 }
    public var revokedIDs: Set<String> { Set(devices.filter { !$0.isApproved }.map(\.id)) }
    public mutating func applyRevocations(_ ids: Set<String>) {
        for id in ids where devices.contains(where: { $0.id == id && $0.isApproved }) { revoke(id: id) }
    }
    public var isValid: Bool {
        hostPin.count == 32 && (revocationJournalVersion == nil || revocationJournalVersion == 1)
            && devices.count <= 64 && Set(devices.map(\.id)).count == devices.count
            && devices.allSatisfy { $0.publicKeyPin.count == 32 && DeviceDisplayName.isValid($0.name) }
    }
}
