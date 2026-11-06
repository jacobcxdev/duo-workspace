import SwiftUI

struct FunctionKeysMenu: View {
    let input: SessionInputController

    var body: some View {
        Menu {
            ForEach(MacFunctionKey.functionKeys) { key in
                Button { input.press(key.code) } label: { Text(key.name) }
                    .accessibilityIdentifier("keyboard.\(key.glyph)")
            }
        } label: {
            Text("F1–F12")
        }
        .accessibilityLabel("Function keys")
        .accessibilityIdentifier("keyboard.functionKeys")
    }
}
