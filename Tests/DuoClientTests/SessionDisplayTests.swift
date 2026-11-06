import Foundation
import Testing
import DuoCore
@testable import DuoWorkspace

@MainActor
struct SessionDisplayTests {
    @Test func transportResetCancelsPendingResizeButKeepsTheLatestMeasurementForReconnect() async throws {
        let name = "DisplayLifecycle.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let delay = ControlledDisplayDelay()
        let display = SessionDisplay(settings: AppSettings(defaults: defaults), delay: delay.wait)
        defer { display.disconnect(); delay.resumeAll() }
        var hellos: [ClientHello] = []
        var resizes: [DesktopResizeRequest] = []
        display.sendHello = { hellos.append($0) }
        display.sendResize = { resizes.append($0) }
        display.begin(mode: .extend, quality: .balanced)
        display.reportViewport(CGSize(width: 951, height: 635))
        display.connectionApproved(adaptive: true, maximumDetail: true)
        #expect(hellos.count == 1)
        display.setVideoReady(true)
        display.reportViewport(CGSize(width: 669, height: 917))
        try await waitForClientState { delay.pending.count == 1 }
        display.resetTransport()
        display.connectionApproved(adaptive: true, maximumDetail: true)
        #expect(hellos.count == 2)
        #expect(hellos.last?.desktop == DesktopSize.viewport(width: 669, height: 917))
        display.setVideoReady(true)
        delay.resumeAll()
        try await waitForClientState { delay.completed == 1 }
        await nextClientMainQueueTurn()
        #expect(resizes.isEmpty)
    }

    @Test func aRetiredHelloDeadlineCannotStartTheReplacementConnection() async throws {
        let name = "DisplayHello.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let delay = ControlledDisplayDelay()
        let display = SessionDisplay(settings: AppSettings(defaults: defaults), delay: delay.wait)
        defer { display.disconnect(); delay.resumeAll() }
        var hellos: [ClientHello] = []
        display.sendHello = { hellos.append($0) }
        display.begin(mode: .extend, quality: .balanced)
        display.connectionApproved(adaptive: true, maximumDetail: true)
        try await waitForClientState { delay.pending.count == 1 }
        let old = delay.pending.removeFirst()
        display.resetTransport()
        display.connectionApproved(adaptive: true, maximumDetail: true)
        try await waitForClientState { delay.pending.count == 1 }
        old.resume()
        try await waitForClientState { delay.completed == 1 }
        await nextClientMainQueueTurn()
        #expect(hellos.isEmpty)
        delay.resumeAll()
        try await waitForClientState { hellos.count == 1 }
    }

    @Test func fullDisconnectDiscardsOldGeometryAndRejectsUnsolicitedDesktopUpdates() throws {
        let name = "DisplayDisconnect.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let display = SessionDisplay(settings: AppSettings(defaults: defaults))
        var hellos: [ClientHello] = []
        display.sendHello = { hellos.append($0) }
        display.begin(mode: .extend, quality: .balanced)
        display.reportViewport(CGSize(width: 951, height: 635))
        display.disconnect()
        #expect(throws: IdentityError.self) {
            try display.receive(DesktopState(revision: 0, desktop: DesktopSize(width: 800, height: 600), ready: true, accepted: true, message: ""))
        }
        display.begin(mode: .extend, quality: .balanced)
        display.reportViewport(CGSize(width: 466, height: 678))
        display.connectionApproved(adaptive: true, maximumDetail: true)
        #expect(hellos.first?.desktop == DesktopSize.viewport(width: 466, height: 678))
        display.disconnect()
    }
}

@MainActor private final class ControlledDisplayDelay {
    var pending: [CheckedContinuation<Void, Never>] = []
    private(set) var completed = 0
    func wait(_ duration: Duration) async {
        await withCheckedContinuation { pending.append($0) }
        completed += 1
    }
    func resumeAll() {
        let ready = pending
        pending.removeAll()
        for continuation in ready { continuation.resume() }
    }
}
