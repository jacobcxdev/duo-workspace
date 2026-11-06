import UIKit
import DuoCore

final class PointerPadView: UIView {
    var onActivate: (() -> Bool)?
    private var nativeTouch: SessionNativeTouch?
    private var nativeContext: UUID?
    private var cancellationID: UInt64 = 0
    private var frameAspect = 1.0
    private var reservesRevealEdges = false
    private var contacts: [ObjectIdentifier: NativeTouchContact] = [:]
    private var nextID: UInt8 = 1
    private var waitingForLift = false
    private var previousBounds = CGRect.zero

    override var editingInteractionConfiguration: UIEditingInteractionConfiguration {
        nativeTouch == nil ? super.editingInteractionConfiguration : .none
    }

    func configureNativeTouch(_ session: SessionNativeTouch?, aspect: Double, reservesEdges: Bool, cancellationID revision: UInt64) {
        let context = session?.status.contextID
        let firstAttachment = nativeTouch == nil
        if nativeTouch !== session || nativeContext != context || frameAspect != aspect {
            cancelNativeTouches()
        } else if cancellationID != revision {
            contacts.removeAll(); waitingForLift = true
        }
        nativeTouch = session; nativeContext = context
        cancellationID = session == nil ? 0 : revision
        frameAspect = aspect; reservesRevealEdges = reservesEdges
        isMultipleTouchEnabled = true
        if firstAttachment { waitingForLift = false }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if previousBounds != .zero && previousBounds != bounds { cancelNativeTouches() }
        previousBounds = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { cancelNativeTouches() }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard nativeTouch?.isReady == true else { super.touchesBegan(touches, with: event); return }
        if event?.allTouches?.allSatisfy({ [.began, .ended, .cancelled].contains($0.phase) }) == true {
            waitingForLift = false
        }
        guard !waitingForLift else { return }
        for touch in touches {
            beginNativeTouch(ObjectIdentifier(touch), at: touch.location(in: self))
        }
        publishNativeTouches()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard nativeTouch?.isReady == true else { super.touchesMoved(touches, with: event); return }
        guard !waitingForLift else { return }
        for touch in touches { moveNativeTouch(ObjectIdentifier(touch), to: touch.location(in: self)) }
        publishNativeTouches()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard nativeTouch != nil else { super.touchesEnded(touches, with: event); return }
        for touch in touches { contacts[ObjectIdentifier(touch)] = nil }
        if event?.allTouches?.allSatisfy({ [.ended, .cancelled].contains($0.phase) }) == true {
            waitingForLift = false
        }
        publishNativeTouches()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelNativeTouches()
        super.touchesCancelled(touches, with: event)
    }

    func cancelNativeTouches() {
        contacts.removeAll(); waitingForLift = true
        nativeTouch?.cancelContacts()
        cancellationID = nativeTouch?.cancellationID ?? 0
    }

    func beginNativeTouch(_ key: ObjectIdentifier, at point: CGPoint) {
        guard !waitingForLift, nativeTouch?.isReady == true, contacts.count < NativeTouchFrame.maximumContacts, contacts[key] == nil,
              !reservesRevealEdges || !ControlsRevealGesture.startsAtEdge(point, in: bounds),
              let normalized = DesktopTouchGeometry.normalized(point, in: bounds, aspect: frameAspect) else { return }
        while contacts.values.contains(where: { $0.id == nextID }) { nextID = nextID == 127 ? 1 : nextID + 1 }
        contacts[key] = NativeTouchContact(id: nextID, x: normalized.x, y: normalized.y)
        nextID = nextID == 127 ? 1 : nextID + 1
    }

    func moveNativeTouch(_ key: ObjectIdentifier, to point: CGPoint) {
        guard !waitingForLift, let contact = contacts[key],
              let normalized = DesktopTouchGeometry.normalized(point, in: bounds, aspect: frameAspect, clamped: true) else { return }
        contacts[key] = NativeTouchContact(id: contact.id, x: normalized.x, y: normalized.y)
    }

    func publishNativeTouches() {
        nativeTouch?.updateContacts(contacts.values.sorted { $0.id < $1.id })
    }

    override func accessibilityActivate() -> Bool {
        isUserInteractionEnabled && (onActivate?() ?? false)
    }
}
