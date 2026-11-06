import SwiftUI

struct SessionMoreMenu: View {
    let input: SessionInputController
    let inputEnabled: Bool
    var hideControls: (() -> Void)?

    var body: some View {
        Menu {
            Button("Right-click", systemImage: "cursorarrow.click") { input.click(right: true) }
                .disabled(!inputEnabled)
            Button("Double-click", systemImage: "cursorarrow.click.2") { input.click(count: 2) }
                .disabled(!inputEnabled)
            Button("Release all keys & buttons", systemImage: "hand.raised", action: input.releaseHeldInput)
            if let hideControls {
                Button("Hide controls", systemImage: "eye.slash", action: hideControls)
                    .accessibilityHint("Swipe inward at either side mark to show controls.")
                    .accessibilityIdentifier("session.hideControls")
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly).font(.title3)
                .frame(minWidth: 44, minHeight: 52)
        }
        .accessibilityLabel("More controls")
    }
}
