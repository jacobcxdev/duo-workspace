import Foundation
import Darwin
import DuoCore

/// Prevents concurrent hosts from overwriting device approval and revocation state.
final class AccessStoreLease: @unchecked Sendable {
    private let descriptor: Int32
    private init(descriptor: Int32) { self.descriptor = descriptor }

    static func acquire(in directory: URL) throws -> AccessStoreLease {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let path = directory.appendingPathComponent("host-access.lock").path
        let descriptor = open(path, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw IdentityError.accessStoreInUse
        }
        return AccessStoreLease(descriptor: descriptor)
    }

    deinit { flock(descriptor, LOCK_UN); close(descriptor) }
}
