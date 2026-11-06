import Foundation
import DuoCore

struct ActiveInvitation {
    let value: PairingInvitation
    let deadline: TimeInterval

    init(value: PairingInvitation, uptime: TimeInterval) {
        self.value = value
        deadline = uptime + PairingInvitation.lifetime
    }

    func isExpired(now: Date, uptime: TimeInterval) -> Bool {
        now >= value.expiresAt || uptime >= deadline
    }
}
