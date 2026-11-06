import SwiftUI

struct SpecialKey: View {
    let key: MacFunctionKey
    let input: SessionInputController

    var body: some View {
        Button { input.press(key.code) } label: {
            Text(key.glyph).font(.system(.callout, design: .monospaced)).frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .background(.quaternary, in: .rect(cornerRadius: 12))
        .accessibilityLabel(Text(key.name))
        .accessibilityInputLabels([Text(key.name), Text(key.glyph)])
    }
}
