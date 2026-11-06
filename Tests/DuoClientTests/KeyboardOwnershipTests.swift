import SwiftUI
import Testing
@testable import DuoWorkspace

@MainActor
struct KeyboardOwnershipTests {
    @Test func coalescedPauseFlushesCommittedTextOnceAndRejectsCanceledDrafts() async throws {
        let suite = "KeyboardFlush.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        let coordinator = RemoteKeyboardField.Coordinator(input: input, focused: .constant(true))
        let field = RemoteTextField()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        defer { withExtendedLifetime(window) {} }
        window.addSubview(field)
        var sent: [String] = []
        input.emit = { if let text = $0.text { sent.append(text) } }
        // The model pauses and resumes before SwiftUI updates acceptsInput.
        input.acceptsInput = { false }
        field.text = "日本"
        coordinator.changed(field)
        input.acceptsInput = { true }
        #expect(coordinator.isAcceptingInput && sent.isEmpty)
        coordinator.schedulePendingTextDelivery(field)
        coordinator.schedulePendingTextDelivery(field)
        #expect(sent.isEmpty) // Never mutate observed state during updateUIView.
        try await waitForClientState { sent == ["日本"] }
        #expect(sent == ["日本"] && field.text == "")

        field.text = "canceled"
        coordinator.schedulePendingTextDelivery(field)
        input.releaseAll()
        try await waitForClientState { field.text == "" }
        #expect(sent == ["日本"] && field.text == "")

        field.text = "old"
        coordinator.schedulePendingTextDelivery(field)
        input.releaseAll()
        coordinator.clearIfReset(field)
        field.text = "new"
        coordinator.schedulePendingTextDelivery(field)
        try await waitForClientState { sent == ["日本", "new"] }
        #expect(sent == ["日本", "new"] && field.text == "")
    }

    @Test func pausingRemoteInputPreservesTheFieldAndPendingComposition() throws {
        let suite = "KeyboardPause.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        let coordinator = RemoteKeyboardField.Coordinator(input: input, focused: .constant(true))
        let field = RemoteTextField()
        field.wantsFocus = true
        field.setMarkedText("にほん", selectedRange: NSRange(location: 3, length: 0))
        coordinator.changed(field)
        var sent: [String] = []
        var hardware = 0, deletes = 0
        input.emit = { if let text = $0.text { sent.append(text) } }
        field.onHardwareKey = { _, _ in hardware += 1 }
        field.onBackspace = { deletes += 1 }
        field.allowsInputNow = { coordinator.isAcceptingInput }
        // Network state changes before SwiftUI updates its native field.
        input.acceptsInput = { false }
        #expect(!coordinator.textFieldShouldReturn(field))
        field.deleteBackward()
        #expect(field.text == "にほん")
        #expect(!coordinator.textFieldShouldReturn(field))
        #expect(!coordinator.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))
        #expect(field.markedTextRange != nil && field.wantsFocus)
        // UIKit may commit an existing draft while input is paused. Keep it
        // locally until the same session resumes, then send it only once.
        field.unmarkText()
        coordinator.changed(field)
        #expect(field.text == "にほん" && sent.isEmpty)
        let command = try #require(field.keyCommands?.first)
        _ = field.perform(command.action, with: command)
        field.deleteBackward()
        #expect(hardware == 0 && deletes == 0 && field.text == "にほん")
        input.acceptsInput = { true }
        coordinator.changed(field)
        coordinator.changed(field)
        #expect(sent == ["にほん"] && field.text == "")
        #expect(input.composition.isEmpty && field.wantsFocus)
    }

    @Test func controlOwnershipUsesFoldSpaceAndAccessibilityInsteadOfKeyboardHeight() {
        let tabletop = CGRect(x: 0, y: 450, width: 669, height: 12)
        let book = CGRect(x: 450, y: 0, width: 12, height: 669)
        #expect(KeyboardControlsOwner.preferred(division: tabletop, lowerPaneCanFitControls: true,
            inputEnabled: true, prefersNativeAccessibility: false) == .workspace)
        for division in [book, nil] {
            #expect(KeyboardControlsOwner.preferred(division: division, lowerPaneCanFitControls: true,
                inputEnabled: true, prefersNativeAccessibility: false) == .inputAccessory)
        }
        #expect(KeyboardControlsOwner.preferred(division: tabletop, lowerPaneCanFitControls: false,
            inputEnabled: true, prefersNativeAccessibility: false) == .inputAccessory)
        #expect(KeyboardControlsOwner.preferred(division: tabletop, lowerPaneCanFitControls: true,
            inputEnabled: false, prefersNativeAccessibility: false) == .inputAccessory)
        #expect(KeyboardControlsOwner.preferred(division: tabletop, lowerPaneCanFitControls: true,
            inputEnabled: true, prefersNativeAccessibility: true) == .inputAccessory)
        #expect(!KeyboardControlsOwner.workspace.hasVisibleAccessory(for: .software))
        #expect(KeyboardControlsOwner.inputAccessory.hasVisibleAccessory(for: .software))
        #expect(!KeyboardControlsOwner.inputAccessory.hasVisibleAccessory(for: .hidden))
        for language in [nil, "ja-JP", "zh-Hans", "ko-KR", "fr-FR", "emoji"] {
            #expect(KeyboardControlsOwner.workspace.forKeyboard(language: language, hasComposedText: false) == .inputAccessory)
        }
        #expect(KeyboardControlsOwner.workspace.forKeyboard(language: "en-US", hasComposedText: false) == .workspace)
        #expect(KeyboardControlsOwner.workspace.forKeyboard(language: "en-GB", hasComposedText: true) == .inputAccessory)
        #expect(KeyboardControlsOwner.inputAccessory.forKeyboard(language: "en-US", hasComposedText: false) == .inputAccessory)
    }

    @Test func movingControlsWaitsForCompositionAndKeepsTheSameField() async throws {
        let suite = "KeyboardOwnership.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        let language = TestKeyboardLanguage()
        let coordinator = RemoteKeyboardField.Coordinator(input: input, focused: .constant(true),
                                                         inputLanguage: { _ in language.value })
        let field = RemoteTextField()
        let accessory = KeyboardAccessoryContainer(content: KeyboardAccessoryView(input: input,
            keyboard: .constant(true), focused: .constant(true)))
        coordinator.accessory = accessory
        field.inputAccessoryView = accessory
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        defer { withExtendedLifetime(window) {} }
        window.addSubview(field)
        field.wantsFocus = true
        let identity = ObjectIdentifier(field)
        var owners: [KeyboardControlsOwner] = []
        var committed: [String] = []
        input.emit = { if $0.kind == .text, let text = $0.text { committed.append(text) } }
        coordinator.controlsOwnerChanged = { owners.append($0) }
        coordinator.requestControlsOwner(.workspace, for: field)
        try await waitForClientState { coordinator.controlsOwner == .workspace }
        #expect(coordinator.controlsOwner == .workspace && field.inputAccessoryView == nil)

        language.value = "ja-JP"
        field.setMarkedText("にほん", selectedRange: NSRange(location: 3, length: 0))
        coordinator.changed(field)
        coordinator.requestControlsOwner(.workspace, for: field)
        await nextClientMainQueueTurn()
        #expect(coordinator.controlsOwner == .workspace)
        #expect(field.inputAccessoryView == nil)
        #expect(field.markedTextRange != nil && input.composition == "にほん")
        #expect(owners == [.workspace] && committed.isEmpty)

        field.unmarkText()
        coordinator.changed(field)
        try await waitForClientState { coordinator.controlsOwner == .inputAccessory }
        #expect(coordinator.controlsOwner == .inputAccessory)
        #expect(field.inputAccessoryView === accessory)
        #expect(ObjectIdentifier(field) == identity && field.wantsFocus)
        #expect(committed == ["にほん"])

        // The notification may precede UIKit updating textInputMode.
        NotificationCenter.default.post(name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
        language.value = "en-US"
        try await waitForClientState { coordinator.controlsOwner == .workspace }
        #expect(coordinator.controlsOwner == .workspace && field.inputAccessoryView == nil)
        #expect(owners == [.workspace, .inputAccessory, .workspace])

        // A keyboard that composes text must retain its candidate area even
        // if it reports English as its primary language.
        field.setMarkedText("café", selectedRange: NSRange(location: 4, length: 0))
        coordinator.changed(field)
        await nextClientMainQueueTurn()
        #expect(coordinator.controlsOwner == .workspace && field.markedTextRange != nil)
        field.unmarkText()
        coordinator.changed(field)
        coordinator.requestControlsOwner(.workspace, for: field)
        try await waitForClientState { coordinator.controlsOwner == .inputAccessory }
        #expect(field.inputAccessoryView === accessory)
        #expect(owners == [.workspace, .inputAccessory, .workspace, .inputAccessory])
        #expect(committed == ["にほん", "café"])
    }

    @Test func unknownComposingKeyboardKeepsNativeControlsWhenLanguageResolves() async throws {
        let suite = "KeyboardOwnership.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        let language = TestKeyboardLanguage()
        language.value = nil
        let coordinator = RemoteKeyboardField.Coordinator(input: input, focused: .constant(true),
                                                         inputLanguage: { _ in language.value })
        let field = RemoteTextField()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        defer { withExtendedLifetime(window) {} }
        window.addSubview(field)
        coordinator.requestControlsOwner(.workspace, for: field)
        field.setMarkedText("かな", selectedRange: NSRange(location: 2, length: 0))
        coordinator.changed(field)
        language.value = "en-US"
        field.unmarkText()
        coordinator.changed(field)
        await nextClientMainQueueTurn()
        #expect(coordinator.controlsOwner == .inputAccessory)
    }
}

@MainActor
private final class TestKeyboardLanguage {
    var value: String? = "en-US"
}
