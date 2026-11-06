import Foundation
import Observation
import DuoCore

@MainActor @Observable
final class HostLibrary {
    private(set) var hosts: [HostProfile]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let credentials: any ClientCredentials

    init(defaults: UserDefaults, credentials: any ClientCredentials) {
        self.defaults = defaults
        self.credentials = credentials
        hosts = defaults.data(forKey: "DuoHosts")
            .flatMap { try? JSONDecoder().decode([HostProfile].self, from: $0) } ?? []
    }

    func update(id: UUID, name: String, address: String, port: UInt16, mode: WorkspaceMode) throws {
        guard let address = HostAddress.normalized(address), port != 0 else { throw HostFormError.address }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80 else { throw HostFormError.name }
        guard let index = hosts.firstIndex(where: { $0.id == id }) else { throw IdentityError.invalidInvitation }
        var updated = hosts
        updated[index].name = name
        updated[index].address = address
        updated[index].port = port
        updated[index].mode = mode
        try store(updated)
    }

    func approve(_ host: HostProfile, pin: Data) throws {
        try credentials.save(HostCredential(publicKeyPin: pin), for: host.id)
        var updated = hosts
        if let index = updated.firstIndex(where: { $0.id == host.id }) { updated[index] = host }
        else { updated.append(host) }
        try store(updated)
    }

    func remove(_ host: HostProfile) throws {
        try credentials.remove(host.id)
        try store(hosts.filter { $0.id != host.id })
    }

    private func store(_ updated: [HostProfile]) throws {
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: "DuoHosts")
        hosts = updated
    }
}
