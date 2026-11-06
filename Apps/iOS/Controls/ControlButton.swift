import SwiftUI

struct ControlButton: View {
    let title: LocalizedStringKey
    let symbol: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: symbol).font(.title3)
                    if selected { Image(systemName: "checkmark").font(.caption.bold()) }
                }
                .accessibilityHidden(true)
                Text(title).font(.caption)
            }
            .frame(minWidth: 56, maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color("OnAccent") : .primary)
        .background(selected ? Color.accentColor : Color.clear, in: .rect(cornerRadius: 12))
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
