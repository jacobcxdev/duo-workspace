import CoreGraphics

enum MacKeyEvents {
    static let modifierCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62, 63]

    static func flags(for held: Set<UInt16>) -> CGEventFlags {
        var flags = CGEventFlags()
        if held.contains(55) || held.contains(54) { flags.insert(.maskCommand) }
        if held.contains(56) || held.contains(60) { flags.insert(.maskShift) }
        if held.contains(58) || held.contains(61) { flags.insert(.maskAlternate) }
        if held.contains(59) || held.contains(62) { flags.insert(.maskControl) }
        if held.contains(63) { flags.insert(.maskSecondaryFn) }
        return flags
    }

    static func make(_ code: UInt16, down: Bool, held: Set<UInt16>) -> CGEvent? {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
        if modifierCodes.contains(code) { event?.type = .flagsChanged }
        event?.flags = flags(for: held)
        return event
    }
}
