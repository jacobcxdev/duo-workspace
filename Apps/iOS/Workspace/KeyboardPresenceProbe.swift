import SwiftUI

/// Tracks the local layout guide, including rotation and hardware-keyboard
/// changes that don't produce a reliable did-show/did-hide sequence.
struct KeyboardPresenceProbe: UIViewRepresentable {
    let changed: (KeyboardPresentation) -> Void

    func makeUIView(context: Context) -> KeyboardPresenceView {
        KeyboardPresenceView(changed: changed)
    }

    func updateUIView(_ view: KeyboardPresenceView, context: Context) {
        view.changed = changed
        view.setNeedsLayout()
    }
}
