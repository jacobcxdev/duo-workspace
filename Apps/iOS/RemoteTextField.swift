import UIKit

final class RemoteTextField: UITextField {
    var onBackspace: (() -> Void)?
    var onHardwareKey: ((UInt16, UIKeyModifierFlags) -> Void)?
    var onCompositionEnded: (() -> Void)?
    var onEnteredWindow: (() -> Void)?
    var onFocusEnding: (() -> Void)?
    var wantsFocus = false
    var allowsInputNow: () -> Bool = { true }
    private var forwardedFunctionPresses = Set<ObjectIdentifier>()
    private var focusRequestScheduled = false

    func forwardFunctionKey(_ usage: UIKeyboardHIDUsage, modifiers: UIKeyModifierFlags) -> Bool {
        guard allowsInputNow(), markedTextRange == nil,
              let key = MacFunctionKey.from(usage) else { return false }
        onHardwareKey?(key.code, modifiers)
        return true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let remaining = presses.filter { press in
            guard let key = press.key, forwardFunctionKey(key.keyCode, modifiers: key.modifierFlags) else { return true }
            forwardedFunctionPresses.insert(ObjectIdentifier(press))
            return false
        }
        if !remaining.isEmpty { super.pressesBegan(Set(remaining), with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let remaining = presses.filter { forwardedFunctionPresses.remove(ObjectIdentifier($0)) == nil }
        if !remaining.isEmpty { super.pressesEnded(Set(remaining), with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let remaining = presses.filter { forwardedFunctionPresses.remove(ObjectIdentifier($0)) == nil }
        if !remaining.isEmpty { super.pressesCancelled(Set(remaining), with: event) }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { onEnteredWindow?() }
        reconcileFocus()
    }

    func reconcileFocus() {
        if !wantsFocus, isFirstResponder {
            onFocusEnding?()
            resignFirstResponder()
        } else if window != nil, wantsFocus, !isFirstResponder, !focusRequestScheduled {
            focusRequestScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.focusRequestScheduled = false
                guard self.window != nil, self.wantsFocus, !self.isFirstResponder else { return }
                self.becomeFirstResponder()
            }
        }
    }

    override func deleteBackward() {
        guard allowsInputNow() else { return }
        if (text ?? "").isEmpty && markedTextRange == nil { onBackspace?() }
        else { super.deleteBackward() }
    }

    override func unmarkText() {
        super.unmarkText()
        onCompositionEnded?()
    }

    override var keyCommands: [UIKeyCommand]? {
        guard markedTextRange == nil else { return super.keyCommands }
        let navigation = MacFunctionKey.editingKeys.compactMap(\.commandInput)
        let commands = navigation.flatMap { key in HardwareModifierMapping.combinations.map { flags in
            UIKeyCommand(input: key, modifierFlags: flags, action: #selector(forwardKey(_:)))
        } } + MacShortcut.allCases.map {
            UIKeyCommand(input: $0.input, modifierFlags: .command, action: #selector(forwardKey(_:)))
        }
        commands.forEach { $0.wantsPriorityOverSystemBehavior = true }
        return commands
    }

    @objc private func forwardKey(_ command: UIKeyCommand) {
        guard allowsInputNow(), let input = command.input, markedTextRange == nil,
              let key = MacFunctionKey.editingKeys.first(where: { $0.commandInput == input })?.code
                ?? MacShortcut.allCases.first(where: { $0.input == input })?.keyCode else { return }
        onHardwareKey?(key, command.modifierFlags)
    }
}
