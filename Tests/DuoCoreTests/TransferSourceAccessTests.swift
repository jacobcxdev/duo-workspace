import Foundation
import Testing
@testable import DuoCore

struct TransferSourceAccessTests {
    @Test func closingSourceReleasesAccessBeforeSourceIsDestroyed() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("test".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        var access: SecurityScopedFileAccess? = SecurityScopedFileAccess(url: url)
        weak let lease = access
        let source = try TransferSource(url: url, access: #require(access))
        access = nil
        #expect(lease != nil)
        await source.close()
        #expect(lease == nil)
        await source.close()
    }

    @Test func finishingSourceReleasesAccessWhileAcknowledgmentIsPending() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        var access: SecurityScopedFileAccess? = SecurityScopedFileAccess(url: url)
        weak let lease = access
        let source = try TransferSource(url: url, access: #require(access))
        access = nil
        _ = try await source.finish()
        #expect(lease == nil)
    }

    @Test func failedOpenDoesNotRetainAccess() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        weak var lease: SecurityScopedFileAccess?
        func openMissingFile() throws {
            let access = SecurityScopedFileAccess(url: url)
            lease = access
            _ = try TransferSource(url: url, access: access)
        }
        #expect(throws: FileTransferError.invalidFile) { try openMissingFile() }
        #expect(lease == nil)
    }
}
