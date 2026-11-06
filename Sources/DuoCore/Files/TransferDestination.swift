import Foundation
import CryptoKit
import Darwin

public actor TransferDestination {
    private let offer: FileOffer
    private let directory: URL
    private let staging: URL
    private let partial: URL
    private let handle: FileHandle
    private var offset: UInt64 = 0
    private var hash = SHA256()

    public init(offer: FileOffer, directory: URL) throws {
        guard offer.isValid, directory.isFileURL else { throw FileTransferError.invalidFile }
        self.offer = offer; self.directory = directory
        staging = directory.appendingPathComponent(".DuoTransfer-\(UUID())", isDirectory: true)
        partial = staging.appendingPathComponent("partial")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let fd = open(partial.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { try? FileManager.default.removeItem(at: staging); throw FileTransferError.storage }
        handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }

    public func append(_ data: Data, at position: UInt64) throws -> UInt64 {
        guard position == offset, !data.isEmpty, data.count <= FileTransferMessage.chunkBytes,
              offset <= offer.size, UInt64(data.count) <= offer.size - offset else { throw FileTransferError.protocolViolation }
        try handle.write(contentsOf: data); hash.update(data: data)
        offset += UInt64(data.count)
        return offset
    }

    public func finish(digest: Data) throws -> URL {
        guard offset == offer.size, digest.count == 32, Data(hash.finalize()) == digest else { throw FileTransferError.integrity }
        try handle.synchronize(); try handle.close()
        let original = URL(fileURLWithPath: offer.name)
        for suffix in 0..<1000 {
            let name: String
            if suffix == 0 { name = offer.name }
            else if original.pathExtension.isEmpty { name = "\(offer.name) (\(suffix + 1))" }
            else { name = "\(original.deletingPathExtension().lastPathComponent) (\(suffix + 1)).\(original.pathExtension)" }
            let destination = directory.appendingPathComponent(name)
            do {
                try FileManager.default.moveItem(at: partial, to: destination)
                try? FileManager.default.removeItem(at: staging)
                return destination
            } catch let error as NSError where error.code == NSFileWriteFileExistsError { continue }
        }
        throw FileTransferError.storage
    }

    public func cancel() { try? handle.close(); try? FileManager.default.removeItem(at: staging) }
    deinit { try? FileManager.default.removeItem(at: staging) }
}
