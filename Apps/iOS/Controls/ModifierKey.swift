import SwiftUI
import DuoCore

struct ModifierKey: View {
    let input: SessionInputController
    let modifier: RemoteModifier
    private var selected: Bool { input.modifiers.contains(modifier) }

    var body: some View {
        Button { input.modifier(modifier) } label: {
            HStack(spacing: 4) {
                Text(modifier.glyph).font(.title3)
                if selected { Image(systemName: "checkmark").font(.caption2.bold()) }
            }
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(modifier == .function && !input.supportsFunctionModifier)
        .foregroundStyle(selected ? Color("OnAccent") : .primary)
        .background(selected ? Color.accentColor : Color.secondary.opacity(0.14), in: .rect(cornerRadius: 12))
        .accessibilityLabel(Text(modifier.name))
        .accessibilityInputLabels([Text(modifier.name), Text(modifier.glyph)])
        .accessibilityValue(selected ? "Held for next action" : "Off")
        .accessibilityHint(modifier == .function && !input.supportsFunctionModifier ? "Update Duo Workspace Host to use Fn." : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
