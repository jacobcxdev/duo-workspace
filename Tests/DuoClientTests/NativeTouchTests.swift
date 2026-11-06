import UIKit
import Testing
import DuoCore
@testable import DuoWorkspace

@MainActor
struct NativeTouchClientTests {
    @Test func nativeContactIDsStayDistinctAndMatchTheVideo() throws {
        let session = SessionNativeTouch()
        session.supported = true; session.sendControl = { _ in true }
        var ended = 0
        session.gestureEnded = { ended += 1 }
        var frames: [NativeTouchFrame] = []
        session.sendFrame = { frames.append($0) }
        session.setEnabled(true)
        session.receive(NativeTouchStatus(.ready, contextID: UUID()))
        defer { session.disconnect() }
        let view = PointerPadView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        view.configureNativeTouch(session, aspect: 2, reservesEdges: false, cancellationID: session.cancellationID)
        let fingers = (0..<6).map { _ in NSObject() }
        view.beginNativeTouch(ObjectIdentifier(fingers[0]), at: CGPoint(x: 200, y: 20))
        view.publishNativeTouches()
        #expect(frames.last?.contacts.isEmpty == true)
        for (index, finger) in fingers.enumerated() {
            view.beginNativeTouch(ObjectIdentifier(finger), at: CGPoint(x: 80 + 40 * index, y: 150))
        }
        view.publishNativeTouches()
        let contacts = try #require(frames.last?.contacts)
        #expect(contacts.count == 5 && Set(contacts.map(\.id)).count == 5)
        #expect(contacts[0].x == 0.2 && contacts[0].y == 0.25)
        view.moveNativeTouch(ObjectIdentifier(fingers[0]), to: CGPoint(x: 900, y: -20))
        view.publishNativeTouches()
        #expect(frames.last?.contacts[0].id == contacts[0].id)
        #expect(frames.last?.contacts[0].x == 1 && frames.last?.contacts[0].y == 0)
        view.cancelNativeTouches()
        #expect(frames.last?.contacts.isEmpty == true)
        #expect(ended == 1)
    }

    @Test func revealEdgesDoNotSendNativeFingers() {
        let session = SessionNativeTouch()
        session.supported = true; session.sendControl = { _ in true }
        var frames: [NativeTouchFrame] = []
        session.sendFrame = { frames.append($0) }
        session.setEnabled(true); session.receive(NativeTouchStatus(.ready, contextID: UUID()))
        defer { session.disconnect() }
        let view = PointerPadView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        view.configureNativeTouch(session, aspect: 1, reservesEdges: true, cancellationID: session.cancellationID)
        let left = NSObject(), right = NSObject()
        view.beginNativeTouch(ObjectIdentifier(left), at: CGPoint(x: 5, y: 200))
        view.beginNativeTouch(ObjectIdentifier(right), at: CGPoint(x: 395, y: 200))
        view.publishNativeTouches()
        #expect(frames.last?.contacts.isEmpty == true)
    }

    @Test func contextChangesDropHeldFingersAndSwitchingOffStopsHeartbeats() async throws {
        let session = SessionNativeTouch()
        session.supported = true
        var controls: [Bool] = [], frames: [NativeTouchFrame] = []
        session.sendControl = { controls.append($0.enabled); return true }
        session.sendFrame = { frames.append($0) }
        session.setEnabled(true)
        let first = UUID(), second = UUID()
        session.receive(NativeTouchStatus(.ready, contextID: first))
        session.updateContacts([.init(id: 1, x: 0.4, y: 0.6)])
        session.receive(NativeTouchStatus(.ready, contextID: second))
        #expect(frames.last?.contextID == second && frames.last?.contacts.isEmpty == true)
        session.setEnabled(false)
        let sent = frames.count
        try await Task.sleep(for: .milliseconds(150))
        #expect(frames.count == sent)
        #expect(controls == [true, false])
        #expect(!session.isReady)
    }

    @Test func externalCancellationPreventsHeldTouchesFromStartingAgain() {
        let session = SessionNativeTouch()
        session.supported = true; session.sendControl = { _ in true }
        var frames: [NativeTouchFrame] = []
        session.sendFrame = { frames.append($0) }
        session.setEnabled(true); session.receive(NativeTouchStatus(.ready, contextID: UUID()))
        defer { session.disconnect() }
        let view = PointerPadView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        view.configureNativeTouch(session, aspect: 1, reservesEdges: false, cancellationID: session.cancellationID)
        let finger = NSObject(), identity = ObjectIdentifier(finger)
        view.beginNativeTouch(identity, at: CGPoint(x: 100, y: 100))
        view.publishNativeTouches()
        session.cancelContacts()
        view.configureNativeTouch(session, aspect: 1, reservesEdges: false, cancellationID: session.cancellationID)
        view.moveNativeTouch(identity, to: CGPoint(x: 200, y: 200))
        view.publishNativeTouches()
        #expect(frames.last?.contacts.isEmpty == true)
    }

    @Test func nativeModeDisablesMouseGestureInterpretation() throws {
        let name = "NativeTouch.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        settings.pointerMode = .nativeTouch
        #expect(AppSettings(defaults: defaults).pointerMode == .nativeTouch)
        let input = SessionInputController(settings: settings)
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        let control = PointerSurface.Coordinator(input: input)
        let view = PointerPadView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        control.installGestures(on: view)
        control.configure(view: view, enabled: true, mode: .nativeTouch, aspect: 1,
                          doubleTapAction: .rightClick, revealControls: nil)
        events = []
        control.click(at: CGPoint(x: 100, y: 100), in: view.bounds, time: 1)
        control.rightClick(at: CGPoint(x: 100, y: 100), in: view.bounds)
        #expect(events.isEmpty)
    }

    @Test func explicitPointerControlsUseLastNativeTouchWithoutExtraMouseMovement() throws {
        let name = "NativePosition.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        let session = SessionNativeTouch()
        session.supported = true; session.sendControl = { _ in true }
        session.positionChanged = { input.rememberNativeTouch($0) }
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        session.setEnabled(true); session.receive(NativeTouchStatus(.ready, contextID: UUID()))
        defer { session.disconnect() }
        session.updateContacts([.init(id: 6, x: 0.25, y: 0.75)])
        #expect(events.isEmpty)
        session.updateContacts([])
        input.click(right: true)
        #expect(events.count == 1)
        #expect(events.first?.kind == .rightClick)
        #expect(events.first?.x == 0.25 && events.first?.y == 0.75)
    }
}
