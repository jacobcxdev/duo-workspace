import SwiftUI

struct PermissionRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let allowed: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: allowed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(allowed ? .green : .primary)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !allowed { Button("Allow", action: action) }
        }
        .padding(.vertical, 4)
    }
}
