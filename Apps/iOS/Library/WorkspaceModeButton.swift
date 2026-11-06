import SwiftUI
import DuoCore

struct WorkspaceModeButton: View {
    let mode: WorkspaceMode
    let primary: Bool
    let connect: (WorkspaceMode) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if primary {
            action.buttonStyle(.borderedProminent).foregroundStyle(Color("OnAccent"))
        } else {
            action.buttonStyle(.bordered)
        }
    }

    private var action: some View {
        Button { connect(mode) } label: {
            Label(mode == .control ? "Control Mac" : "Use as Display", systemImage: mode == .control ? "cursorarrow" : "display.2")
                .labelStyle(.titleAndIcon)
                .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
        }
        .controlSize(.large)
        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
        .accessibilityHint(mode == .control ? "Shows and controls the Mac’s current desktop" : "Creates a separate workspace on the Mac")
    }
}
