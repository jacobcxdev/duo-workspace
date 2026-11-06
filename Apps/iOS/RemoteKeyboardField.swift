import SwiftUI

/// Keeps UIKit's text composition intact while the keyboard controls move.
struct RemoteKeyboardField: UIViewRepresentable {
    let input: SessionInputController
    @Binding var focused: Bool
    @Binding var keyboard: Bool
    var enabled = true
    var controlsEnabled = true
    var softwareKeyboardVisible = false
    var requestedControlsOwner = KeyboardControlsOwner.inputAccessory
    var controlsOwnerChanged: (KeyboardControlsOwner) -> Void = { _ in }
    var showSession: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(input: input, focused: $focused) }

    func makeUIView(context: Context) -> RemoteTextField {
        let field = RemoteTextField()
        field.borderStyle = .roundedRect
        field.placeholder = "Type on your Mac"
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.accessibilityLabel = String(localized: "Type on Mac")
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.returnKeyType = .default
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.onBackspace = { [weak coordinator = context.coordinator] in coordinator?.input.press(51) }
        field.onHardwareKey = { [weak coordinator = context.coordinator] key, flags in
            coordinator?.input.hardwareKey(key, modifiers: flags)
        }
        field.allowsInputNow = { [weak coordinator = context.coordinator] in coordinator?.isAcceptingInput == true }
        field.onCompositionEnded = { [weak coordinator = context.coordinator, weak field] in
            guard let field else { return }
            coordinator?.retryControlsOwner(for: field)
        }
        field.onEnteredWindow = field.onCompositionEnded
        field.onFocusEnding = { [weak coordinator = context.coordinator, weak field] in
            guard let field else { return }
            coordinator?.cancelDraft(field)
        }
        let accessory = KeyboardAccessoryContainer(content: KeyboardAccessoryView(input: input, keyboard: $keyboard,
            focused: $focused, softwareKeyboardVisible: softwareKeyboardVisible, inputEnabled: controlsEnabled, showSession: showSession))
        context.coordinator.accessory = accessory
        field.inputAccessoryView = accessory
        return field
    }

    func updateUIView(_ field: RemoteTextField, context: Context) {
        let coordinator = context.coordinator
        coordinator.input = input
        coordinator.focused = $focused
        coordinator.controlsOwnerChanged = controlsOwnerChanged
        coordinator.clearIfReset(field)
        field.wantsFocus = focused && enabled
        coordinator.accessory?.host.rootView = KeyboardAccessoryView(input: input, keyboard: $keyboard,
            focused: $focused, softwareKeyboardVisible: softwareKeyboardVisible, inputEnabled: controlsEnabled, showSession: showSession)
        coordinator.schedulePendingTextDelivery(field)
        coordinator.requestControlsOwner(requestedControlsOwner, for: field)
        field.reconcileFocus()
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var input: SessionInputController
        var focused: Binding<Bool>
        var accessory: KeyboardAccessoryContainer?
        var isAcceptingInput: Bool { input.acceptsInput() }
        var controlsOwnerChanged: (KeyboardControlsOwner) -> Void = { _ in }
        private(set) var controlsOwner = KeyboardControlsOwner.inputAccessory
        private var requestedOwner = KeyboardControlsOwner.inputAccessory
        private var ownerUpdateScheduled = false
        private weak var keyboardField: RemoteTextField?
        private let inputLanguage: @MainActor (RemoteTextField) -> String?
        private var composingLanguages = Set<String>()
        private var resetID: UInt64
        private var clearing = false
        private var textDeliveryScheduled = false

        init(input: SessionInputController, focused: Binding<Bool>,
             inputLanguage: @escaping @MainActor (RemoteTextField) -> String? = { $0.textInputMode?.primaryLanguage }) {
            self.input = input
            self.focused = focused
            self.inputLanguage = inputLanguage
            self.resetID = input.keyboardResetID
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(inputModeChanged),
                name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        func clearIfReset(_ field: UITextField) {
            guard resetID != input.keyboardResetID else { return }
            resetID = input.keyboardResetID
            cancelDraft(field)
        }

        func cancelDraft(_ field: UITextField) {
            clearing = true
            field.text = ""
            field.unmarkText()
            clearing = false
        }

        func schedulePendingTextDelivery(_ field: RemoteTextField) {
            guard isAcceptingInput, !textDeliveryScheduled, field.markedTextRange == nil,
                  field.text?.isEmpty == false else { return }
            textDeliveryScheduled = true
            let generation = input.keyboardResetID
            Task { @MainActor [weak self, weak field] in
                guard let self else { return }
                self.textDeliveryScheduled = false
                guard let field, field.window != nil, self.isAcceptingInput else { return }
                guard self.resetID == generation, self.input.keyboardResetID == generation else {
                    self.clearIfReset(field)
                    self.schedulePendingTextDelivery(field)
                    return
                }
                self.changed(field)
            }
        }

        func requestControlsOwner(_ owner: KeyboardControlsOwner, for field: RemoteTextField) {
            requestedOwner = owner
            retryControlsOwner(for: field)
        }

        func retryControlsOwner(for field: RemoteTextField, recheckInputMode: Bool = false) {
            keyboardField = field
            guard !ownerUpdateScheduled,
                  recheckInputMode || effectiveOwner(for: field) != controlsOwner else { return }
            ownerUpdateScheduled = true
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self else { return }
                self.ownerUpdateScheduled = false
                guard let field, field.window != nil, field.markedTextRange == nil else { return }
                let owner = self.effectiveOwner(for: field)
                guard owner != self.controlsOwner else { return }
                let wasFirstResponder = field.isFirstResponder
                if wasFirstResponder { self.input.releaseHeldInput() }
                field.inputAccessoryView = owner == .inputAccessory ? self.accessory : nil
                self.controlsOwner = owner
                if wasFirstResponder { field.reloadInputViews() }
                self.controlsOwnerChanged(self.controlsOwner)
            }
        }

        private func effectiveOwner(for field: RemoteTextField) -> KeyboardControlsOwner {
            let language = inputLanguage(field)?.lowercased()
            return requestedOwner.forKeyboard(language: language,
                hasComposedText: composingLanguages.contains("") || composingLanguages.contains(language ?? ""))
        }

        @objc private func inputModeChanged() {
            guard let field = keyboardField else { return }
            // UIKit can post the notification before the field's mode changes.
            retryControlsOwner(for: field, recheckInputMode: true)
        }

        @objc func changed(_ field: UITextField) {
            guard !clearing else { return }
            guard resetID == input.keyboardResetID else { clearIfReset(field); return }
            guard isAcceptingInput else { return }
            if field.markedTextRange != nil {
                input.composition = field.text ?? ""
                if let field = field as? RemoteTextField {
                    composingLanguages.insert(inputLanguage(field)?.lowercased() ?? "")
                    retryControlsOwner(for: field)
                }
                return
            }
            input.composition = ""
            if let text = field.text, !text.isEmpty {
                field.text = ""
                input.type(text)
            }
            if let field = field as? RemoteTextField { retryControlsOwner(for: field) }
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            guard resetID == input.keyboardResetID else { clearIfReset(field); return false }
            guard isAcceptingInput else { return false }
            guard field.markedTextRange == nil else { return true }
            changed(field)
            input.press(36)
            return false
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard resetID == input.keyboardResetID else { clearIfReset(textField); return false }
            return isAcceptingInput
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            focused.wrappedValue = true
            if let field = field as? RemoteTextField { retryControlsOwner(for: field, recheckInputMode: true) }
        }
        func textFieldDidEndEditing(_ field: UITextField) {
            if let field = field as? RemoteTextField { retryControlsOwner(for: field) }
        }
    }
}
