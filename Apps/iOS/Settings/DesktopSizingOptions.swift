import SwiftUI
import DuoCore

struct DesktopSizingOptions: View {
    @Binding var selection: DesktopSizing
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(DesktopSizing.allCases, id: \.rawValue) { sizing in
                    Button {
                        selection = sizing
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sizing.title).foregroundStyle(.primary)
                                Text(sizing.explanation).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark")
                                .opacity(selection == sizing ? 1 : 0).accessibilityHidden(true)
                        }
                    }
                    .accessibilityAddTraits(selection == sizing ? .isSelected : [])
                }
            } footer: {
                Text("A fixed shape keeps its display match until you choose Update display match. Automatic follows the current workspace.")
            }
        }
        .navigationTitle("Workspace size")
        .navigationBarTitleDisplayMode(.inline)
    }
}
