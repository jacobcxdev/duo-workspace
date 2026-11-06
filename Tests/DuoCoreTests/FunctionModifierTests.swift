import Testing
@testable import DuoCore

struct FunctionModifierTests {
    @Test func fnMapsNavigationAndDeleteThenReleases() {
        let pairs: [(UInt16, UInt16)] = [(51,117), (36,76), (123,115), (124,119), (126,116), (125,121)]
        for (source, destination) in pairs {
            var input = RemoteInputState()
            #expect(input.toggleModifier(.function).first?.keyCode == 63)
            let events = input.press(source)
            #expect(events.map(\.keyCode) == [destination, destination, 63])
            #expect(events.map(\.kind) == [.keyDown, .keyUp, .keyUp])
            #expect(input.modifiers.isEmpty)
        }
    }

    @Test func fnAllowsShiftSelectionAndPreservesSystemShortcutArrows() {
        var input = RemoteInputState()
        _ = input.toggleModifier(.function); _ = input.toggleModifier(.shift)
        #expect(input.press(123).first?.keyCode == 115)
        for modifier in [RemoteModifier.control, .option, .command] {
            _ = input.toggleModifier(.function); _ = input.toggleModifier(modifier)
            #expect(input.press(123).first?.keyCode == 123)
            #expect(input.modifiers.isEmpty)
        }
    }

    @Test func fnStaysHeldThroughDragAndIsClearedByRelease() {
        var input = RemoteInputState()
        _ = input.toggleModifier(.function); _ = input.beginDrag()
        #expect(input.finishNativeTouch().isEmpty)
        #expect(input.modifiers.contains(.function))
        #expect(input.endDrag().last?.keyCode == 63)
        _ = input.toggleModifier(.function)
        #expect(input.releaseAll().first?.kind == .releaseAll)
        #expect(input.modifiers.isEmpty)
    }
}
