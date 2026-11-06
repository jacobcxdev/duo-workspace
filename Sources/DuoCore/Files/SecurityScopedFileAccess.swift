import Foundation

final class SecurityScopedFileAccess: Sendable {
    private let url: URL
    private let acquired: Bool

    init(url: URL) {
        self.url = url
        acquired = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if acquired { url.stopAccessingSecurityScopedResource() }
    }
}
