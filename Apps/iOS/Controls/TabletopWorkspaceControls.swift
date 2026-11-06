import SwiftUI

struct TabletopWorkspaceControls: View {
    let model: SessionModel
    @Binding var keyboard: Bool
    @Binding var keyboardFocused: Bool
    let presentation: KeyboardPresentation
    let owner: KeyboardControlsOwner
    let minimumHeight: CGFloat
    let showSession: () -> Void
    var hideControls: (() -> Void)?

    private var showsWorkspaceKeys: Bool { keyboard && owner == .workspace }

    var body: some View {
        VStack(spacing: 0) {
            if showsWorkspaceKeys {
                // The keyboard guide covers its transparent top margin too.
                // Keep the row in the full pane so its buttons remain tappable.
                KeyboardAccessoryView(input: model.input, keyboard: $keyboard, focused: $keyboardFocused,
                                      softwareKeyboardVisible: presentation.hasSoftwareKeys,
                                      inputEnabled: model.canSendInput, showSession: showSession)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(model.input.composition.isEmpty ? 1 : 0)
                    .allowsHitTesting(model.input.composition.isEmpty)
                    .accessibilityHidden(!model.input.composition.isEmpty)
            }
            KeyboardAvoidingRegion {
                TabletopControlDeck(model: model, keyboard: $keyboard, keyboardFocused: $keyboardFocused,
                                    nativeControlsVisible: owner.hasVisibleAccessory(for: presentation),
                                    functionRowInWorkspace: showsWorkspaceKeys,
                                    minimumHeight: showsWorkspaceKeys ? max(160, minimumHeight - KeyboardAccessoryMetrics.minimumHeight) : minimumHeight,
                                    showSession: showSession, hideControls: hideControls)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
