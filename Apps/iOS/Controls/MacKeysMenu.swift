import SwiftUI
import DuoCore

struct MacKeysMenu: View {
    @Bindable var input: SessionInputController

    var body: some View {
        Menu {
            Section("Keys") {
                FunctionKeysMenu(input: input)
                ForEach(MacFunctionKey.editingKeys) { key in
                    Button { input.press(key.code) } label: { Text(key.name) }
                }
            }
            Section("Modifiers") {
                ForEach(RemoteModifier.allCases, id: \.self) { modifier in
                    Toggle(isOn: $input[dynamicMember: \.[held: modifier]]) { Text(modifier.name) }
                        .menuActionDismissBehavior(.disabled)
                        .disabled(modifier == .function && !input.supportsFunctionModifier)
                }
            }
            Section("Shortcuts") {
                ForEach(MacShortcut.menuItems) { shortcut in
                    Button { input.shortcut(shortcut.keyCode) } label: { Text(shortcut.name) }
                }
            }
        } label: { Label("Mac keys", systemImage: "keyboard") }
        .accessibilityIdentifier("session.macKeys")
    }
}
