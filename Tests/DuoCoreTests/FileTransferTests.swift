import Foundation
import CryptoKit
import Testing
@testable import DuoCore

@MainActor struct FileTransferTests {
    @Test func acknowledgedTransferPreservesBytesAndExistingFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceFolder = root.appendingPathComponent("source"), destinationFolder = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        let name = "Café 日本語.bin"
        let content = Data((0..<170_003).map { UInt8($0 % 251) })
        let original = destinationFolder.appendingPathComponent(name)
        try Data("Keep me".utf8).write(to: original)
        let sourceURL = sourceFolder.appendingPathComponent(name)
        try content.write(to: sourceURL)
        let sender = FileTransferEngine(), receiver = FileTransferEngine()
        var queue: [(Bool, FileTransferMessage)] = []
        sender.send = { queue.append((true, $0)) }
        receiver.send = { queue.append((false, $0)) }
        await sender.sendFile(sourceURL)
        for _ in 0..<40 {
            guard !queue.isEmpty else { break }
            let (toReceiver, packet) = queue.removeFirst()
            #expect(try JSONEncoder().encode(packet).count <= 128 * 1024)
            if toReceiver {
                try await receiver.receive(packet)
                if receiver.state == .awaitingAcceptance { await receiver.accept(into: destinationFolder) }
            } else { try await sender.receive(packet) }
        }
        #expect(sender.state == .completed && receiver.state == .completed)
        #expect(sender.transferred == UInt64(content.count))
        let received = try #require(receiver.receivedURL)
        #expect(received != original)
        #expect(try Data(contentsOf: original) == Data("Keep me".utf8))
        #expect(try Data(contentsOf: received) == content)
        #expect(try FileManager.default.contentsOfDirectory(atPath: destinationFolder.path).count == 2)
    }

    @Test func corruptOrCancelledTransferNeverPublishesPartialFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let writer = try TransferDestination(offer: FileOffer(name: "test.txt", size: 4), directory: root)
        _ = try await writer.append(Data("data".utf8), at: 0)
        await #expect(throws: FileTransferError.integrity) { try await writer.finish(digest: Data(repeating: 0, count: 32)) }
        await writer.cancel()
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        let pending = try TransferDestination(offer: FileOffer(name: "cancelled.txt", size: 8), directory: root)
        _ = try await pending.append(Data("part".utf8), at: 0)
        await #expect(throws: FileTransferError.protocolViolation) { try await pending.append(Data("bad".utf8), at: 0) }
        await pending.cancel()
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func fileNamesLinksAndGrowingSourcesAreRejected() async throws {
        for name in ["../outside", "/tmp/file", "folder\\file", ".", "..", "bad\nname", "file:stream"] {
            #expect(!FileOffer(name: name, size: 1).isValid)
        }
        #expect(!FileOffer(name: "huge", size: FileOffer.maximumSize + 1).isValid)
        #expect(FileOffer(name: "Family 👨‍👩‍👧‍👦.jpg", size: 1).isValid)
        #expect(!FileOffer(name: "report\u{202E}txt.exe", size: 1).isValid)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("file"), link = root.appendingPathComponent("link")
        try Data("before".utf8).write(to: file)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        #expect(throws: FileTransferError.invalidFile) { try TransferSource(url: link) }
        let reader = try TransferSource(url: file)
        _ = try await reader.read()
        try Data("after and longer".utf8).write(to: file)
        await #expect(throws: FileTransferError.changed) { try await reader.finish() }
        await reader.close()
    }

    @Test func emptyFilesFinishWithoutADataChunk() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = try TransferDestination(offer: FileOffer(name: "empty", size: 0), directory: root)
        let file = try await destination.finish(digest: Data(SHA256.hash(data: Data())))
        #expect(try Data(contentsOf: file).isEmpty)
    }
}
