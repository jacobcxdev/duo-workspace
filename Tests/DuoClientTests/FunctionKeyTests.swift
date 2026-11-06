import UIKit
import Testing
import DuoCore
@testable import DuoWorkspace

@MainActor
struct FunctionKeyTests {
    @Test func allTwelveFunctionKeysHaveCorrectMacCodes() {
        #expect(MacFunctionKey.functionKeys.map(\.code) == [122,120,99,118,96,97,98,100,101,109,103,111])
        #expect(Set(MacFunctionKey.allCases.map(\.id)).count == MacFunctionKey.allCases.count)
        for (index, key) in MacFunctionKey.functionKeys.enumerated() {
            let usage = UIKeyboardHIDUsage(rawValue: 0x3A + index)!
            #expect(MacFunctionKey.from(usage) == key)
        }
    }

    @Test func hardwareFunctionKeysKeepSelectedFnAndOtherModifiers() throws {
        let name = "FunctionKeys.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        input.supportsFunctionModifier = true
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        input.modifier(.function)
        events.removeAll()
        input.hardwareKey(122, modifiers: [.control, .shift])
        #expect(!events.contains { $0.kind == .releaseAll })
        #expect(events.contains { $0.kind == .keyDown && $0.keyCode == 122 })
        #expect(events.contains { $0.kind == .keyDown && $0.keyCode == 59 })
        #expect(events.contains { $0.kind == .keyDown && $0.keyCode == 56 })
        #expect(events.last?.kind == .keyUp && events.last?.keyCode == 63)
        #expect(input.modifiers.isEmpty)
    }

    @Test func functionKeysUseKeyEventsAndRespectInputGate() {
        let field = RemoteTextField()
        var received: [(UInt16, UIKeyModifierFlags)] = []
        field.onHardwareKey = { received.append(($0, $1)) }
        #expect(field.forwardFunctionKey(.keyboardF12, modifiers: [.command]))
        #expect(received.count == 1 && received.first?.0 == 111 && received.first?.1 == .command)
        #expect(field.text?.isEmpty != false)
        field.allowsInputNow = { false }
        #expect(!field.forwardFunctionKey(.keyboardF1, modifiers: []))
        #expect(received.count == 1)
    }

    @Test func fnWaitsForHostSupport() throws {
        let name = "LegacyFunctionKeys.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        input.modifier(.function)
        #expect(events.isEmpty && input.modifiers.isEmpty)
        input.press(122)
        #expect(events.map(\.keyCode) == [122, 122])
        input.supportsFunctionModifier = true
        input.modifier(.function)
        #expect(input.modifiers.contains(.function))
        input.releaseHeldInput()
        #expect(input.modifiers.isEmpty)
    }
}
