import Foundation
import Darwin
import DuoCore

/// Public revocation identifiers, signed by the host identity. Required once
/// migrated: a missing/corrupt record must not silently restore device access.
final class SignedRevocations: RevocationPersisting, @unchecked Sendable {
    private let identity: LocalIdentity
    let url: URL
    private static let maximumBytes = 65_536

    init(identity: LocalIdentity, url: URL) { self.identity = identity; self.url = url }

    static func defaultURL() throws -> URL {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw IdentityError.invalidRevocationRecord
        }
        return support.appendingPathComponent("DuoWorkspace/Security/Revocations-v1.json")
    }

    func load() throws -> Set<String>? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard let data = try handle.read(upToCount: Self.maximumBytes + 1), data.count <= Self.maximumBytes,
              let envelope = try? JSONDecoder().decode(RevocationEnvelope.self, from: data),
              identity.verifyRevocationRecord(envelope.payload, signature: envelope.signature),
              let record = try? JSONDecoder().decode(RevocationRecord.self, from: envelope.payload),
              record.version == 1, record.hostPin == identity.publicKeyPin,
              record.deniedIDs.count <= 256,
              Set(record.deniedIDs).count == record.deniedIDs.count,
              record.deniedIDs.allSatisfy(Self.isValidID) else { throw IdentityError.invalidRevocationRecord }
        return Set(record.deniedIDs)
    }

    func save(_ deniedIDs: Set<String>) throws {
        guard deniedIDs.count <= 256, deniedIDs.allSatisfy(Self.isValidID) else { throw IdentityError.invalidRevocationRecord }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(RevocationRecord(version: 1, hostPin: identity.publicKeyPin, deniedIDs: deniedIDs.sorted()))
        let envelope = RevocationEnvelope(payload: payload, signature: try identity.signRevocationRecord(payload))
        let data = try encoder.encode(envelope)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
        let descriptor = open(directory.path, O_RDONLY | O_DIRECTORY)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(descriptor) }
        guard fsync(descriptor) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    private static func isValidID(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}
