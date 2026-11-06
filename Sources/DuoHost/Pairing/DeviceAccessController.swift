import Foundation
import Observation
import DuoCore

@MainActor @Observable
public final class DeviceAccessController {
    public private(set) var isReady = false
    public private(set) var loading = false
    public private(set) var message = "Reading saved pairing data…"
    public private(set) var storageWarning: String?
    public private(set) var devices: [PairedDevice] = []
    public private(set) var pending: [PairingRequest] = []
    public var invitation: PairingInvitation? { activeInvitation?.value }
    private var activeInvitation: ActiveInvitation?
    @ObservationIgnored public private(set) var identity: LocalIdentity?
    @ObservationIgnored private var registry: DeviceRegistry?
    @ObservationIgnored private var deniedIDs = Set<String>()
    @ObservationIgnored private var revocations: (any RevocationPersisting)?
    @ObservationIgnored private var storageLease: AccessStoreLease?
    @ObservationIgnored var onDecision: ((UUID, AuthorizationResult) -> Void)?
    @ObservationIgnored var onRevoke: ((String) -> Void)?
    @ObservationIgnored var onStorageFailure: (() -> Void)?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    nonisolated private static let registryAccount = "host-devices-v2"
    @ObservationIgnored private let persist: (DeviceRegistry) throws -> Void
    @ObservationIgnored private let uptime: () -> TimeInterval

    public init() {
        uptime = { ProcessInfo.processInfo.systemUptime }
        persist = { registry in
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--simulate-keychain-write-failure") { throw IdentityError.keychain(-25308) }
            #endif
            try IdentityStore.save(JSONEncoder().encode(registry), account: Self.registryAccount)
        }
        load(allowInteraction: false)
    }

    init(identity: LocalIdentity, registry: DeviceRegistry,
         revocations: any RevocationPersisting,
         deniedIDs: Set<String> = [], uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         persist: @escaping (DeviceRegistry) throws -> Void) {
        self.identity = identity; self.registry = registry; self.persist = persist
        self.revocations = revocations; self.deniedIDs = deniedIDs.union(registry.revokedIDs); self.uptime = uptime
        refreshDevices(); isReady = true; message = "Ready"
    }

    public func load(allowInteraction: Bool = true) {
        if registry != nil, storageWarning != nil { retryStorage(); return }
        guard !loading, !isReady else { return }
        loading = true
        Task {
            let result = await Task.detached { () -> Result<(LocalIdentity, DeviceRegistry, SignedRevocations, Set<String>, AccessStoreLease), Error> in
                Result {
                    let location = try SignedRevocations.defaultURL()
                    let lease = try AccessStoreLease.acquire(in: location.deletingLastPathComponent())
                    let saved = try IdentityStore.load(Self.registryAccount, allowInteraction: allowInteraction)
                    guard saved == nil || saved!.count <= 128 * 1024 else { throw IdentityError.invalidIdentity }
                    var registry = try saved.map { try JSONDecoder().decode(DeviceRegistry.self, from: $0) }
                    let hasJournal = FileManager.default.fileExists(atPath: location.path)
                    let identity = try LocalIdentity.loadOrCreate(account: "host-identity-v2", allowInteraction: allowInteraction,
                                                                requireExisting: registry != nil || hasJournal)
                    if registry == nil { registry = DeviceRegistry(hostPin: identity.publicKeyPin) }
                    guard let loaded = registry else { throw IdentityError.invalidIdentity }
                    let journal = SignedRevocations(identity: identity, url: location)
                    let prepared = try Self.prepareRegistry(loaded, identity: identity, revocations: journal) {
                        try IdentityStore.save(JSONEncoder().encode($0), account: Self.registryAccount)
                    }
                    return (identity, prepared.0, journal, prepared.1, lease)
                }
            }.value
            loading = false
            switch result {
            case .success(let (identity, registry, revocations, denied, lease)):
                self.identity = identity; self.registry = registry; self.revocations = revocations; deniedIDs = denied
                storageLease = lease
                refreshDevices(); isReady = true; message = "Ready"
                let knownDenied = Set(registry.devices.map(\.id)).intersection(denied)
                if !knownDenied.isSubset(of: registry.revokedIDs) {
                    storageWarning = "Revoked devices are blocked. Retry saving to update Keychain."
                }
            case .failure(let error):
                message = error.localizedDescription
                #if DEBUG
                if case IdentityError.keychain(let status) = error { message += " (\(status))" }
                #endif
            }
        }
    }

    nonisolated static func prepareRegistry(_ registry: DeviceRegistry, identity: LocalIdentity,
                                            revocations: any RevocationPersisting,
                                            persist: (DeviceRegistry) throws -> Void) throws -> (DeviceRegistry, Set<String>) {
        guard registry.isValid, LocalIdentity.matches(registry.hostPin, identity.publicKeyPin) else { throw IdentityError.invalidIdentity }
        var loaded = registry
        let record = try revocations.load()
        guard record != nil || loaded.revocationJournalVersion == nil else { throw IdentityError.invalidRevocationRecord }
        let denied = (record ?? []).union(loaded.revokedIDs)
        if record == nil { try revocations.save(denied) }
        if loaded.revocationJournalVersion == nil { loaded.requireRevocationJournal(); try persist(loaded) }
        return (loaded, denied)
    }

    public func makeInvitation(name: String, address: String) {
        guard isReady, let identity else { return }
        do {
            let invitation = try PairingInvitation(name: name, address: address, hostPin: identity.publicKeyPin)
            activeInvitation = ActiveInvitation(value: invitation, uptime: uptime())
            message = "Valid for five minutes and one device."
            expiryTask?.cancel()
            expiryTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(PairingInvitation.lifetime)) } catch { return }
                self?.cancelInvitation()
            }
        } catch { message = error.localizedDescription }
    }

    public func cancelInvitation() { activeInvitation = nil; expiryTask?.cancel() }

    func authorize(pin: Data, request: AuthorizationRequest, connectionID: UUID, verificationCode: String, now: Date = Date()) -> AuthorizationResult {
        guard isReady, request.isValid, pin.count == 32 else { return AuthorizationResult(.denied, message: "Device approval is unavailable.") }
        if approvedDevice(pin: pin) != nil { return AuthorizationResult(.approved, message: "Device approved") }
        guard let token = request.invitationToken else {
            let revoked = deniedIDs.contains(LocalIdentity.identifier(pin)) || registry?.device(pin: pin)?.revokedAt != nil
            return AuthorizationResult(revoked ? .revoked : .denied,
                message: revoked ? "Your Mac revoked access. Create a new invitation to pair again." : "This device isn’t paired. Create an invitation on your Mac.")
        }
        guard let activeInvitation, !activeInvitation.isExpired(now: now, uptime: uptime()),
              LocalIdentity.matches(token, activeInvitation.value.token) else {
            return AuthorizationResult(.denied, message: "This invitation expired or was already used. Create a new one.")
        }
        cancelInvitation()
        pending.append(PairingRequest(id: connectionID, name: request.deviceName, publicKeyPin: pin,
            expiresAt: now.addingTimeInterval(PairingRequest.lifetime), verificationCode: verificationCode, deadline: uptime() + PairingRequest.lifetime))
        message = "Compare the codes, then approve or decline."
        return AuthorizationResult(.pending, message: "Waiting for approval on your Mac.")
    }

    public func approve(_ id: UUID) {
        guard isReady, let request = pending.first(where: { $0.id == id }),
              !request.isExpired(now: Date(), uptime: uptime()), var next = registry, let revocations else { deny(id); return }
        let deviceID = LocalIdentity.identifier(request.publicKeyPin)
        do {
            // Save denial first so a failed approval write leaves access blocked.
            let held = deniedIDs.union([deviceID])
            try revocations.save(held)
            deniedIDs = held
            try next.approve(pin: request.publicKeyPin, name: request.name)
            next.requireRevocationJournal()
            try persist(next)
            registry = next
            let committed = deniedIDs.subtracting([deviceID])
            try revocations.save(committed)
            deniedIDs = committed
            refreshDevices()
            removePending(id)
            storageWarning = nil
            message = "Access saved"
            onDecision?(id, AuthorizationResult(.approved, message: "Device approved"))
        } catch {
            let failure = error.localizedDescription
            // A write can commit before throwing. Restore denial in both stores.
            deniedIDs.insert(deviceID)
            if var rejected = registry {
                rejected.revoke(id: deviceID); rejected.requireRevocationJournal()
                registry = rejected; refreshDevices(); onRevoke?(deviceID)
                let saved = persistDeniedState(rejected)
                if !saved.journal && !saved.keychain {
                    isReady = false; cancelInvitation(); onStorageFailure?()
                }
            }
            deny(id)
            storageWarning = "Pairing wasn’t saved. \(failure)"
                + (isReady ? "" : " Sharing is off until storage is repaired.")
            message = storageWarning!
        }
    }

    public func deny(_ id: UUID) {
        removePending(id)
        message = "Pairing declined or expired. Create a new invitation to try again."
        onDecision?(id, AuthorizationResult(.denied, message: "Your Mac declined the request, or approval timed out."))
    }

    func expirePendingRequests() {
        let now = uptime()
        for request in pending where request.isExpired(now: Date(), uptime: now) { deny(request.id) }
    }

    func cancelRequest(_ id: UUID) {
        if pending.contains(where: { $0.id == id }) {
            removePending(id)
            message = "Pairing ended. Create a new invitation to try again."
        }
    }

    public func revoke(_ id: String) {
        guard var next = registry, next.devices.contains(where: { $0.id == id }) else { return }
        deniedIDs.insert(id); next.revoke(id: id); next.requireRevocationJournal()
        registry = next; refreshDevices()
        onRevoke?(id) // Stop active access before any storage operation can block.
        let saved = persistDeniedState(next)
        switch (saved.journal, saved.keychain) {
        case (true, true): storageWarning = nil; message = "Access revoked"
        case (true, false): storageWarning = "Access revoked. Retry saving to update Keychain."; message = storageWarning!
        case (false, true): storageWarning = "Access revoked. Retry saving to update the recovery file."; message = storageWarning!
        case (false, false):
            isReady = false; cancelInvitation()
            storageWarning = "Revocation couldn’t be saved. Sharing is off. Repair storage, then retry saving."
            message = storageWarning!; onStorageFailure?()
        }
    }

    public func retryStorage() {
        guard var next = registry, let revocations else { return }
        next.applyRevocations(deniedIDs); next.requireRevocationJournal()
        do {
            try revocations.save(deniedIDs)
            try persist(next)
            registry = next; refreshDevices(); isReady = true
            storageWarning = nil; message = "Access saved"
        } catch { message = "Still can’t save access. \(error.localizedDescription)" }
    }

    func approvedDevice(pin: Data) -> PairedDevice? {
        guard isReady, !deniedIDs.contains(LocalIdentity.identifier(pin)), let device = registry?.device(pin: pin), device.isApproved else { return nil }
        return device
    }

    private func refreshDevices() {
        guard var effective = registry else { devices = []; return }
        effective.applyRevocations(deniedIDs)
        devices = effective.devices
    }

    private func persistDeniedState(_ next: DeviceRegistry) -> (journal: Bool, keychain: Bool) {
        let journal = Result { guard let revocations else { throw IdentityError.invalidRevocationRecord }; try revocations.save(deniedIDs) }
        let keychain = Result { try persist(next) }
        return ((try? journal.get()) != nil, (try? keychain.get()) != nil)
    }

    private func removePending(_ id: UUID) {
        pending.removeAll { $0.id == id }
    }
}
