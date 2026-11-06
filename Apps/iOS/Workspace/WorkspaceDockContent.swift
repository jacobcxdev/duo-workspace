import SwiftUI

struct WorkspaceDockContent: View {
    let model: SessionModel
    @Binding var keyboard: Bool
    @Binding var keyboardFocused: Bool
    let chrome: WorkspaceChrome
    let showSession: () -> Void
    let hideControls: () -> Void
    let width: CGFloat

    var body: some View {
        // Keep the hidden size to prevent the controls reflowing during reveal.
        ControlDeck(model: model, keyboard: $keyboard, keyboardFocused: $keyboardFocused,
                    showSession: showSession, hideControls: hideControls)
            .frame(width: width)
            .clipShape(.rect(cornerRadius: 20))
            .modifier(WorkspaceChromeEffect(visible: chrome.isVisible))
    }
}
