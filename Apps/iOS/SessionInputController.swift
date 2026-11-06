import SwiftUI
import Observation
import DuoCore

@MainActor @Observable
final class SessionInputController {
    private(set) var isDragging = false
    private(set) var isScrolling = false
    private(set) var modifiers = Set<RemoteModifier>()
    var supportsFunctionModifier = false
    var composition = ""
    private(set) var keyboardResetID: UInt64 = 0
    @ObservationIgnored var emit: ((InputEvent) -> Void)?
    @ObservationIgnored var acceptsInput: () -> Bool = { true }
    @ObservationIgnored private var state = RemoteInputState()
    private let settings: AppSettings

    init(settings: AppSettings) { self.settings = settings }

    private func send(_ events: [InputEvent]) {
        if isDragging != state.isDragging { isDragging = state.isDragging }
        if isScrolling != state.isScrolling { isScrolling = state.isScrolling }
        if modifiers != state.modifiers { modifiers = state.modifiers }
        events.forEach { emit?($0) }
    }

    func move(_ delta: CGPoint, in size: CGSize) {
        if state.isScrolling { scroll(delta); return }
        send(state.move(dx: delta.x * settings.pointerSpeed, dy: delta.y * settings.pointerSpeed,
                        width: size.width, height: size.height))
    }
    func finishScroll() { send(state.finishScroll()) }
    func finishNativeTouch() { send(state.finishNativeTouch()) }
    func move(to point: CGPoint) { send(state.move(toX: point.x, y: point.y)) }
    func rememberNativeTouch(_ contact: NativeTouchContact) {
        state.rememberPosition(x: contact.x, y: contact.y)
    }
    func scroll(_ delta: CGPoint) {
        let direction = settings.naturalScrolling ? 1.0 : -1.0
        send(state.scroll(dx: delta.x * direction, dy: delta.y * direction))
    }
    func nudgePointer(dx: Double, dy: Double) {
        if state.isScrolling { send(state.toggleScroll()) }
        send(state.move(dx: dx * 0.01 * settings.pointerSpeed, dy: dy * 0.01 * settings.pointerSpeed,
                        width: 1, height: 1))
    }
    func scrollContent(dx: Double, dy: Double) {
        send(state.scroll(dx: dx, dy: dy))
        send(state.finishScroll())
    }
    func click(right: Bool = false, count: Int = 1) { send(state.click(right: right, count: count)) }
    func toggleDrag() { send(state.isDragging ? state.endDrag() : state.beginDrag()) }
    func beginDrag() { send(state.beginDrag()) }
    func endDrag() { send(state.endDrag()) }
    func toggleScroll() { send(state.toggleScroll()) }
    func modifier(_ modifier: RemoteModifier) {
        guard modifier != .function || supportsFunctionModifier else { return }
        send(state.toggleModifier(modifier))
    }
    subscript(held modifier: RemoteModifier) -> Bool {
        get { modifiers.contains(modifier) }
        set { if newValue != modifiers.contains(modifier) { self.modifier(modifier) } }
    }
    func press(_ key: UInt16) { send(state.press(key)) }
    func type(_ text: String) {
        var chunk = ""
        for character in text {
            let next = String(character)
            if chunk.utf8.count + next.utf8.count > InputEvent.maximumTextBytes { send(state.type(chunk)); chunk = "" }
            guard next.utf8.count <= InputEvent.maximumTextBytes else { continue }
            chunk += next
        }
        send(state.type(chunk))
    }
    func shortcut(_ key: UInt16) {
        send(state.releaseAll())
        send(state.toggleModifier(.command))
        send(state.press(key))
    }
    func hardwareKey(_ key: UInt16, modifiers flags: UIKeyModifierFlags) {
        if state.isDragging || state.isScrolling { send(state.releaseAll()) }
        for (flag, modifier) in HardwareModifierMapping.bindings {
            if flags.contains(flag), !state.modifiers.contains(modifier) { send(state.toggleModifier(modifier)) }
        }
        send(state.press(key))
    }
    func releaseHeldInput() { send(state.releaseAll()) }
    func releaseAll() { composition = ""; keyboardResetID &+= 1; releaseHeldInput() }
}
