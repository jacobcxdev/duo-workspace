import SwiftUI
import DuoCore

struct DesktopSizingPicker: View {
    @Binding var selection: DesktopSizing

    var body: some View {
        NavigationLink {
            DesktopSizingOptions(selection: $selection)
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Workspace size").fixedSize()
                    Spacer()
                    Text(selection.title).foregroundStyle(.secondary).fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workspace size")
                    Text(selection.title).foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("settings.desktopSizing")
    }
}
