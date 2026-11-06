import Foundation
import DuoCore

struct PairingPlan {
    let invitation: PairingInvitation
    let host: HostProfile

    init(_ invitation: PairingInvitation, name: String?, mode: WorkspaceMode, replacing id: UUID?) throws {
        guard invitation.expiresAt > Date() else { throw IdentityError.expiredInvitation }
        let name = (name ?? invitation.name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80 else { throw HostFormError.name }
        self.invitation = invitation
        host = HostProfile(id: id ?? UUID(), name: name, address: invitation.address, port: invitation.port, mode: mode)
    }
}
