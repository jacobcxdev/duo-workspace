import SwiftUI

struct SessionActions: View {
    let input: SessionInputController
    let keyboardActive: Bool
    let keyboardAction: () -> Void
    let inputEnabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            ControlButton(title: keyboardActive ? "Stop typing" : "Keyboard",
                          symbol: keyboardActive ? "keyboard.chevron.compact.down" : "keyboard",
                          selected: keyboardActive) {
                input.releaseHeldInput()
                keyboardAction()
            }
            ControlButton(title: input.isDragging ? "Drop" : "Drag", symbol: input.isDragging ? "hand.point.up.left.fill" : "hand.point.up.left",
                          selected: input.isDragging, action: input.toggleDrag)
            ControlButton(title: "Scroll", symbol: "arrow.up.arrow.down",
                          selected: input.isScrolling, action: input.toggleScroll)
            ControlButton(title: "Right-click", symbol: "cursorarrow.click") { input.click(right: true) }
        }
        .disabled(!inputEnabled)
    }
}
