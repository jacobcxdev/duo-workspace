import SwiftUI
import DuoCore

struct WorkspaceLaunchActions: View {
    let mode: WorkspaceMode
    let connect: (WorkspaceMode) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var otherMode: WorkspaceMode { mode == .control ? .extend : .control }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                WorkspaceModeButton(mode: mode, primary: true, connect: connect)
                WorkspaceModeButton(mode: otherMode, primary: false, connect: connect)
            }.labelStyle(.titleOnly)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    WorkspaceModeButton(mode: mode, primary: true, connect: connect)
                    WorkspaceModeButton(mode: otherMode, primary: false, connect: connect)
                }
                VStack(spacing: 12) {
                    WorkspaceModeButton(mode: mode, primary: true, connect: connect)
                    WorkspaceModeButton(mode: otherMode, primary: false, connect: connect)
                }
            }
        }
    }
}
