import SwiftUI

struct SessionToolbar: View {
    let input: SessionInputController
    let keyboardActive: Bool
    let keyboardAction: () -> Void
    let inputEnabled: Bool
    let showSession: () -> Void
    var hideControls: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                SessionActions(input: input, keyboardActive: keyboardActive, keyboardAction: keyboardAction, inputEnabled: inputEnabled)
                ScrollView(.horizontal) {
                    SessionActions(input: input, keyboardActive: keyboardActive, keyboardAction: keyboardAction, inputEnabled: inputEnabled)
                }.scrollIndicators(.hidden)
            }
            .layoutPriority(1)
            ControlButton(title: "Session", symbol: "slider.horizontal.3", action: showSession)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityIdentifier("session.controls")
                .accessibilityHint("Settings, clipboard, sound and files")
            SessionMoreMenu(input: input, inputEnabled: inputEnabled, hideControls: hideControls)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
