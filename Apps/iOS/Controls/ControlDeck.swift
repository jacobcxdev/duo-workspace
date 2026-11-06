import SwiftUI

struct ControlDeck: View {
    let model: SessionModel
    @Binding var keyboard: Bool
    @Binding var keyboardFocused: Bool
    let showSession: () -> Void
    var hideControls: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            if model.files.choosingOnMac { MacFileSelectionNotice(cancel: model.files.cancel) }
            if keyboard {
                KeyboardAccessoryView(input: model.input, keyboard: $keyboard, focused: $keyboardFocused,
                                      softwareKeyboardVisible: false, inputEnabled: model.canSendInput,
                                      showSession: showSession)
            } else {
                ModifierStrip(input: model.input)
                    .disabled(!model.canSendInput)
                SessionToolbar(input: model.input, keyboardActive: false, keyboardAction: {
                    keyboard = true; keyboardFocused = true
                }, inputEnabled: model.canSendInput, showSession: showSession, hideControls: hideControls)
            }
        }
        .padding(10)
        .background(.regularMaterial)
    }
}
