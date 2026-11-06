import SwiftUI
import DuoCore

struct KeyboardAccessoryView: View {
    let input: SessionInputController
    @Binding var keyboard: Bool
    @Binding var focused: Bool
    var softwareKeyboardVisible = true
    var inputEnabled = true
    var showSession: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Menu("Keyboard controls", systemImage: "keyboard.chevron.compact.down") {
                Button("Switch to pointer", systemImage: "cursorarrow") { keyboard = false }
                Button(focused ? (softwareKeyboardVisible ? "Hide keyboard" : "Stop typing") : "Resume typing") {
                    input.releaseHeldInput()
                    focused.toggle()
                }
                ForEach(MacShortcut.menuItems) { shortcut in
                    Button { input.shortcut(shortcut.keyCode) } label: { Text(shortcut.name) }
                }
                .disabled(!inputEnabled || !input.composition.isEmpty)
                Button("Release all keys & buttons", action: input.releaseHeldInput)
            }
            .labelStyle(.iconOnly).font(.title3).frame(minWidth: 44, minHeight: 44)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(RemoteModifier.allCases, id: \.self) { modifier in
                        ModifierKey(input: input, modifier: modifier).fixedSize(horizontal: true, vertical: false)
                    }
                    FunctionKeysMenu(input: input)
                        .font(.system(.callout, design: .monospaced))
                        .frame(minWidth: 68, minHeight: 44)
                        .background(.quaternary, in: .rect(cornerRadius: 12))
                    ForEach(MacFunctionKey.editingKeys) { key in SpecialKey(key: key, input: input) }
                }
            }
            .scrollIndicators(.hidden)
            .disabled(!inputEnabled || !input.composition.isEmpty)
            if let showSession {
                Button("Session", systemImage: "slider.horizontal.3", action: showSession)
                    .labelStyle(.iconOnly).font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("session.controls")
                    .accessibilityHint("Settings, clipboard, sound and files")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
        .tint(.accentColor)
    }
}
