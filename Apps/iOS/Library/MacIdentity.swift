import SwiftUI
import DuoCore

struct MacIdentity: View {
    let host: HostProfile
    let edit: () -> Void
    let forget: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text(host.name).font(.headline)
                Text(host.address).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                MacOptionsMenu(edit: edit, forget: forget)
            }
        } else {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "desktopcomputer").font(.largeTitle).foregroundStyle(Color.accentColor).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.name).font(.headline)
                    Text(host.address).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer(minLength: 0)
                MacOptionsMenu(edit: edit, forget: forget)
            }
        }
    }
}
