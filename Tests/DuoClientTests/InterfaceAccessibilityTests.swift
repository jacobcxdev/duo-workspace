import SwiftUI
import Testing
import DuoCore
@testable import DuoWorkspace

@MainActor
struct InterfaceAccessibilityTests {
    @Test func combinedHardwareNavigationReachesTheMacWithItsModifiers() throws {
        let field = RemoteTextField()
        let flags: UIKeyModifierFlags = [.control, .shift]
        let command = try #require(field.keyCommands?.first {
            $0.input == UIKeyCommand.inputLeftArrow && $0.modifierFlags == flags
        })
        var received: [(UInt16, UIKeyModifierFlags)] = []
        field.onHardwareKey = { received.append(($0, $1)) }
        _ = field.perform(command.action, with: command)
        #expect(received.count == 1)
        #expect(received.first?.0 == 123 && received.first?.1 == flags)
    }

    @Test func modifierMenuBindingDoesNotToggleOnRepeatedAssignments() throws {
        let suite = "InterfaceAccessibility.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        input[held: .command] = true
        input[held: .command] = true
        #expect(input[held: .command])
        #expect(events.map(\.kind) == [.keyDown])
        input[held: .command] = false
        input[held: .command] = false
        #expect(!input[held: .command])
        #expect(events.map(\.kind) == [.keyDown, .keyUp])
    }
    @Test func accessoryHeightScalesWithTextAndKeepsTouchTargets() {
        let normal = KeyboardAccessoryMetrics.height(for: UITraitCollection(preferredContentSizeCategory: .large))
        let accessible = KeyboardAccessoryMetrics.height(for: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        #expect(accessible > normal)
        for category in [UIContentSizeCategory.extraSmall, .small, .medium, .large, .extraExtraExtraLarge,
                         .accessibilityMedium, .accessibilityExtraExtraExtraLarge] {
            let height = KeyboardAccessoryMetrics.height(for: UITraitCollection(preferredContentSizeCategory: category))
            #expect(height >= KeyboardAccessoryMetrics.minimumHeight)
            #expect(height.isFinite)
        }
    }

    @Test func namedScrollActionsIgnoreTouchDirectionAndReleaseOneShotModifiers() throws {
        let name = "InterfaceAccessibility.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        let input = SessionInputController(settings: settings)
        let control = PointerSurface.Coordinator(input: input)
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        for natural in [true, false] {
            settings.naturalScrolling = natural
            input.modifier(.shift)
            events.removeAll()
            #expect(control.accessibleScrollUp())
            #expect(events.first?.kind == .scroll)
            #expect(events.first?.y == 60)
            #expect(events.last?.kind == .keyUp)
            #expect(events.last?.keyCode == RemoteModifier.shift.keyCode)
            #expect(input.modifiers.isEmpty)
            events.removeAll()
            #expect(control.accessibleScrollDown())
            #expect(events.last?.y == -60)
        }
    }

    @Test func accessibilityMovementMovesThePointerWhileScrollModeWasSelected() throws {
        let name = "InterfaceAccessibility.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        let control = PointerSurface.Coordinator(input: input)
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        input.toggleScroll()
        #expect(input.isScrolling)
        events.removeAll()
        #expect(control.accessibleMoveLeft())
        #expect(!input.isScrolling)
        #expect(events.last?.kind == .move)
        #expect(try #require(events.last?.x) < 0.5)
        #expect(!events.contains { $0.kind == .scroll })
        #expect(control.accessibleMoveRight())
        #expect(abs(try #require(events.last?.x) - 0.5) < 0.0001)
    }

    @Test func accessibilityScrollPreservesDragModifiersUntilDrop() throws {
        let name = "InterfaceAccessibility.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        let control = PointerSurface.Coordinator(input: input)
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        input.modifier(.option)
        input.beginDrag()
        events.removeAll()
        #expect(control.accessibleScrollDown())
        #expect(input.isDragging && input.modifiers.contains(.option))
        #expect(events.count == 1 && events.first?.kind == .scroll)
        #expect(control.accessibleDrag())
        #expect(!input.isDragging && input.modifiers.isEmpty)
        #expect(events.contains { $0.kind == .leftUp })
        #expect(events.last?.kind == .keyUp)
    }

    @Test func disabledAccessibilityActionsCannotEmitRemoteInput() throws {
        let name = "InterfaceAccessibility.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        let control = PointerSurface.Coordinator(input: input)
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        control.isEnabled = false
        #expect(!control.accessibleClick())
        #expect(!control.accessibleRightClick())
        #expect(!control.accessibleDrag())
        #expect(!control.accessibleMoveUp())
        #expect(!control.accessibleScrollDown())
        #expect(!control.accessibleRelease())
        #expect(events.isEmpty)
    }

    @Test func scrollModePanReleasesItsModifierWithoutChangingPointerPanBehavior() throws {
        let name = "InterfaceAccessibility.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        let control = PointerSurface.Coordinator(input: input)
        let surface = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let gesture = TestPanGesture()
        surface.addGestureRecognizer(gesture)
        var events: [InputEvent] = []
        input.emit = { events.append($0) }

        input.modifier(.shift)
        gesture.reportedState = .began
        control.pan(gesture)
        gesture.reportedState = .ended
        gesture.reportedTranslation = CGPoint(x: 10, y: 10)
        control.pan(gesture)
        #expect(input.modifiers.contains(.shift))
        #expect(events.last?.kind == .move)

        input.toggleScroll()
        events.removeAll()
        gesture.reportedState = .began
        control.pan(gesture)
        gesture.reportedState = .changed
        gesture.reportedTranslation = CGPoint(x: 0, y: 20)
        control.pan(gesture)
        // A mode change before the final touch must not strand the modifier.
        input.toggleScroll()
        gesture.reportedState = .ended
        control.pan(gesture)
        #expect(input.modifiers.isEmpty)
        #expect(events.contains { $0.kind == .scroll })
        #expect(events.last?.kind == .keyUp)
    }

    @Test func returnDuringCompositionDefersToUIKitWithoutSendingAMacKey() throws {
        let name = "InterfaceAccessibility.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        let coordinator = RemoteKeyboardField.Coordinator(input: input, focused: .constant(true))
        let field = RemoteTextField()
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        field.setMarkedText("にほん", selectedRange: NSRange(location: 3, length: 0))
        #expect(field.markedTextRange != nil)
        #expect(coordinator.textFieldShouldReturn(field))
        #expect(events.isEmpty)
        #expect(field.markedTextRange != nil)
        field.unmarkText()
        #expect(!coordinator.textFieldShouldReturn(field))
        #expect(events.map(\.kind) == [.text, .keyDown, .keyUp])
        #expect(events.first?.text == "にほん")
        #expect(events.suffix(2).allSatisfy { $0.keyCode == 36 })
    }

    @Test func remoteHardwareCommandsYieldToMarkedTextEditing() throws {
        let field = RemoteTextField()
        let command = try #require(field.keyCommands?.first { $0.input == UIKeyCommand.inputUpArrow })
        var forwarded: [UInt16] = []
        field.onHardwareKey = { key, _ in forwarded.append(key) }
        field.setMarkedText("にほん", selectedRange: NSRange(location: 3, length: 0))
        #expect(field.keyCommands?.contains { $0.action == command.action } != true)
        _ = field.perform(command.action, with: command)
        #expect(forwarded.isEmpty)
        field.unmarkText()
        #expect(field.keyCommands?.contains { $0.action == command.action } == true)
        _ = field.perform(command.action, with: command)
        #expect(forwarded == [126])
    }
}
