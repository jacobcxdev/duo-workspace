import Foundation
import DuoCore

@MainActor
final class HostConnection {
    let id = UUID()
    let channel: SecureChannel
    let createdAt = ProcessInfo.processInfo.systemUptime
    var lastMessage = ProcessInfo.processInfo.systemUptime
    var peerPin: Data?
    var authorizationRequested = false
    var authorized = false
    var authorizedAt: TimeInterval?
    var waitingApproval = false
    var reconfiguringUntil: TimeInterval?
    var clipboardBudget = TrafficBudget(capacity: 4, perSecond: 2)
    var nativeTouchControlBudget = TrafficBudget(capacity: 6, perSecond: 2)
    var microphoneControlBudget = TrafficBudget(capacity: 10, perSecond: 4)
    var purpose = ConnectionPurpose.workspace
    var files: HostFileSession?
    init(channel: SecureChannel) { self.channel = channel }
    func isExpired(now: TimeInterval, captureStarted: Bool) -> Bool {
        if let deadline = reconfiguringUntil { return now > deadline || now - lastMessage > 12 }
        if waitingApproval { return false } // The approval controller owns this deadline.
        if !authorized { return now - createdAt > 15 || now - lastMessage > 12 }
        return now - lastMessage > 12 || (!captureStarted && now - (authorizedAt ?? createdAt) > 20)
    }
}
