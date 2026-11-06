import CoreGraphics
import Foundation
import Testing
import DuoCore
@testable import DuoHost

@MainActor
struct NativeTouchControllerTests {
    @Test func missingPlatformDeviceReportsUnavailableWithoutStartingInput() async {
        let controller = NativeTouchController(supported: true, allowed: { true }, makeDevice: { nil })
        await controller.setEnabled(true, displayID: 1)
        #expect(controller.status == NativeTouchStatus(.unavailable, failure: .macOSVersion))
        #expect(!controller.hasContacts)
        controller.stop()
    }

    @Test func contextRequiresNeutralAndRejectsStaleFramesAfterResize() async throws {
        let device = TestTouchDevice()
        let control = NativeTouchController(supported: true, allowed: { true }, makeDevice: { device })
        await control.setEnabled(true, displayID: CGMainDisplayID())
        defer { control.stop() }
        let first = try #require(control.status.contextID)
        let finger = NativeTouchContact(id: 96, x: 0.3, y: 0.7)
        #expect(!control.receive(NativeTouchFrame(contextID: first, contacts: [finger])))
        #expect(control.receive(NativeTouchFrame(contextID: first, contacts: [])))
        #expect(control.receive(NativeTouchFrame(contextID: first, contacts: [finger])))
        control.suspend()
        #expect(device.releases > 0)
        await control.waitForRelease()
        #expect(device.stops == 1)
        await control.resume(displayID: CGMainDisplayID())
        let second = try #require(control.status.contextID)
        #expect(first != second)
        #expect(!control.receive(NativeTouchFrame(contextID: first, contacts: [finger])))
        #expect(control.receive(NativeTouchFrame(contextID: second, contacts: [])))
        #expect(control.receive(NativeTouchFrame(contextID: second, contacts: [finger])))
    }

    @Test func timeoutReleasesContactsAndRotatesContext() async throws {
        let device = TestTouchDevice()
        var time = 10.0
        let control = NativeTouchController(supported: true, allowed: { true }, now: { time }, makeDevice: { device })
        await control.setEnabled(true, displayID: CGMainDisplayID())
        defer { control.stop() }
        let context = try #require(control.status.contextID)
        control.receive(NativeTouchFrame(contextID: context, contacts: []))
        control.receive(NativeTouchFrame(contextID: context, contacts: [.init(id: 1, x: 0.5, y: 0.5)]))
        time += 0.8
        control.checkLiveness()
        #expect(device.releases == 1)
        #expect(control.status.contextID != context)
        #expect(!control.receive(NativeTouchFrame(contextID: context, contacts: [])))
    }

    @Test func permissionLossStopsDeviceAndUnsupportedHostNeverCreatesOne() async {
        let device = TestTouchDevice()
        var allowed = true
        let control = NativeTouchController(supported: true, allowed: { allowed }, makeDevice: { device })
        await control.setEnabled(true, displayID: CGMainDisplayID())
        allowed = false
        control.checkLiveness()
        await control.waitForRelease()
        #expect(control.status == NativeTouchStatus(.unavailable, failure: .permission))
        #expect(device.releases == 1 && device.stops == 1)
        control.stop()
        let unsupported = NativeTouchController(supported: false, allowed: { true }, makeDevice: { device })
        await unsupported.setEnabled(true, displayID: CGMainDisplayID())
        #expect(device.starts == 1)
        #expect(unsupported.status == NativeTouchStatus(.unavailable, failure: .macOSVersion))
        unsupported.stop()
    }

    @Test func stoppingDuringActivationCannotInstallLateDevice() async {
        let device = TestTouchDevice()
        device.holdStart = true
        let control = NativeTouchController(supported: true, allowed: { true }, makeDevice: { device })
        let pending = Task { await control.setEnabled(true, displayID: CGMainDisplayID()) }
        while device.startContinuation == nil { await Task.yield() }
        control.stop()
        device.startContinuation?.resume(); device.startContinuation = nil
        await pending.value
        #expect(control.status.state == .off)
        #expect(device.stops == 1)
    }

    @Test func permissionLossDuringActivationReportsFailure() async {
        let device = TestTouchDevice()
        device.holdStart = true
        var allowed = true
        let control = NativeTouchController(supported: true, allowed: { allowed }, makeDevice: { device })
        let pending = Task { await control.setEnabled(true, displayID: CGMainDisplayID()) }
        while device.startContinuation == nil { await Task.yield() }
        allowed = false
        device.startContinuation?.resume(); device.startContinuation = nil
        await pending.value
        #expect(control.status == NativeTouchStatus(.unavailable, failure: .permission))
        #expect(device.stops == 1)
        control.stop()
    }
}

@MainActor
private final class TestTouchDevice: NativeTouchDevice {
    func waitForLift() async {}
    var onFailure: ((String) -> Void)?
    var frames: [[NativeTouchContact]] = []
    var starts = 0
    var stops = 0
    var releases = 0
    var holdStart = false
    var startContinuation: CheckedContinuation<Void, Never>?
    func start(displayID: CGDirectDisplayID) async throws {
        starts += 1
        if holdStart { await withCheckedContinuation { startContinuation = $0 } }
    }
    func enqueue(_ contacts: [NativeTouchContact]) { frames.append(contacts) }
    func releaseAll() { releases += 1 }
    func stop() async { stops += 1 }
}
