import SwiftUI

struct MacOptionsMenu: View {
    let edit: () -> Void
    let forget: () -> Void

    var body: some View {
        Menu("Mac options", systemImage: "ellipsis") {
            Button("Edit Mac", systemImage: "pencil", action: edit)
            Button("Forget Mac", systemImage: "trash", role: .destructive, action: forget)
        }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
    }
}
