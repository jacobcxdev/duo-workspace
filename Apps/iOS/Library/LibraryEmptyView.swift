import SwiftUI

struct LibraryEmptyView: View {
    let add: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ContentUnavailableView {
            Label("Your Mac on Duo", systemImage: "display.2")
        } description: {
            Text("Control your Mac or add a display. Start sharing in Duo Workspace Host, then add your Mac here.")
        } actions: {
            Button("Add Mac", systemImage: "plus", action: add)
                .labelStyle(.titleAndIcon)
                .buttonStyle(.borderedProminent).foregroundStyle(Color("OnAccent"))
                .controlSize(.large)
                .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
                .accessibilityIdentifier("library.empty.add")
        }
    }
}
