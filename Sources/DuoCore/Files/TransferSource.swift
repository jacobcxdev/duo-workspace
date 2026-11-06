import Foundation
import CryptoKit
import Darwin

public actor TransferSource {
    public nonisolated let offer: FileOffer
    private let handle: FileHandle
    private var access: SecurityScopedFileAccess?
    private let modified: timespec
    private var offset: UInt64 = 0
    private var hash = SHA256()

    public init(url: URL) throws {
        try self.init(url: url, access: SecurityScopedFileAccess(url: url))
    }

    init(url: URL, access: SecurityScopedFileAccess) throws {
        guard url.isFileURL else { throw FileTransferError.invalidFile }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw FileTransferError.invalidFile }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_size >= 0 else {
            Darwin.close(fd); throw FileTransferError.invalidFile
        }
        let offer = FileOffer(name: url.lastPathComponent, size: UInt64(info.st_size))
        guard offer.size <= FileOffer.maximumSize else { Darwin.close(fd); throw FileTransferError.tooLarge }
        guard offer.isValid else { Darwin.close(fd); throw FileTransferError.invalidFile }
        self.offer = offer; modified = info.st_mtimespec
        self.access = access
        handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }

    public func read() throws -> Data {
        guard offset < offer.size else { return Data() }
        let count = Int(min(UInt64(FileTransferMessage.chunkBytes), offer.size - offset))
        let data = try handle.read(upToCount: count) ?? Data()
        guard !data.isEmpty else { throw FileTransferError.changed }
        offset += UInt64(data.count); hash.update(data: data)
        return data
    }

    public func finish() throws -> Data {
        var info = stat()
        guard offset == offer.size, fstat(handle.fileDescriptor, &info) == 0, UInt64(info.st_size) == offer.size,
              info.st_mtimespec.tv_sec == modified.tv_sec, info.st_mtimespec.tv_nsec == modified.tv_nsec else {
            throw FileTransferError.changed
        }
        try handle.close()
        access = nil
        return Data(hash.finalize())
    }

    public func close() { try? handle.close(); access = nil }
}
