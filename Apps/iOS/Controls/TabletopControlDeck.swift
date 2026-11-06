import SwiftUI

struct TabletopControlDeck: View {
    let model: SessionModel
    @Binding var keyboard: Bool
    @Binding var keyboardFocused: Bool
    let nativeControlsVisible: Bool
    let functionRowInWorkspace: Bool
    let minimumHeight: CGFloat
    let showSession: () -> Void
    var hideControls: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            if WorkspaceLayoutPolicy.showsTabletopTrackpad(availableHeight: geometry.size.height, minimumHeight: minimumHeight) {
                VStack(spacing: 8) {
                    if model.files.choosingOnMac { MacFileSelectionNotice(cancel: model.files.cancel) }
                    if keyboard && !nativeControlsVisible && !functionRowInWorkspace {
                        KeyboardAccessoryView(input: model.input, keyboard: $keyboard, focused: $keyboardFocused,
                                              softwareKeyboardVisible: false, inputEnabled: model.canSendInput, showSession: showSession)
                    }
                    TrackpadView(input: model.input, showHints: model.settings.showHints)
                        .frame(minHeight: 80, maxHeight: .infinity)
                        .disabled(!model.canSendInput)
                    if !keyboard && !nativeControlsVisible { ModifierStrip(input: model.input).disabled(!model.canSendInput) }
                    SessionToolbar(input: model.input, keyboardActive: keyboardFocused, keyboardAction: toggleKeyboard,
                                   inputEnabled: model.canSendInput, showSession: showSession, hideControls: hideControls)
                }
                .padding(10)
            } else {
                ViewThatFits(in: .vertical) {
                    SessionToolbar(input: model.input, keyboardActive: keyboardFocused, keyboardAction: toggleKeyboard,
                                   inputEnabled: model.canSendInput, showSession: showSession, hideControls: hideControls)
                        .padding(10)
                    Color.clear
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    private func toggleKeyboard() {
        if keyboardFocused { keyboardFocused = false }
        else { keyboard = true; keyboardFocused = true }
    }
}
