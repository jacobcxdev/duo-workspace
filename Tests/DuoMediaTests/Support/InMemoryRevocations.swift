import Foundation
import DuoCore
@testable import DuoHost

final class InMemoryRevocations: RevocationPersisting, @unchecked Sendable {
    private let lock = NSLock()
    private var values: Set<String>
    init(_ values: Set<String> = []) { self.values = values }
    func load() throws -> Set<String>? { lock.lock(); defer { lock.unlock() }; return values }
    func save(_ deniedIDs: Set<String>) throws { lock.lock(); defer { lock.unlock() }; values = deniedIDs }
}

extension DeviceAccessController {
    convenience init(identity: LocalIdentity, registry: DeviceRegistry,
                     deniedIDs: Set<String> = [],
                     uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                     persist: @escaping (DeviceRegistry) throws -> Void) {
        self.init(identity: identity, registry: registry, revocations: InMemoryRevocations(),
                  deniedIDs: deniedIDs, uptime: uptime, persist: persist)
    }
}
