import SwiftUI
import DuoCore

struct MacCard: View {
    let host: HostProfile
    let connect: (WorkspaceMode) -> Void
    let edit: () -> Void
    let forget: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MacIdentity(host: host, edit: edit, forget: forget)
            WorkspaceLaunchActions(mode: host.mode, connect: connect)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
    }
}
