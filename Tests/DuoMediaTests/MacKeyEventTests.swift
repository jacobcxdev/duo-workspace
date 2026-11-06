import AppKit
import CoreGraphics
import Testing
@testable import DuoHost

struct MacKeyEventTests {
    @Test func fnUsesFlagsChangedAndItsOwnModifierFlag() throws {
        let down = try #require(MacKeyEvents.make(63, down: true, held: [63, 55]))
        #expect(down.type == .flagsChanged)
        #expect(down.getIntegerValueField(.keyboardEventKeycode) == 63)
        #expect(down.flags.contains([.maskSecondaryFn, .maskCommand]))
        let native = try #require(NSEvent(cgEvent: down))
        #expect(native.modifierFlags.contains(.function))
        let up = try #require(MacKeyEvents.make(63, down: false, held: [55]))
        #expect(up.type == .flagsChanged)
        #expect(!up.flags.contains(.maskSecondaryFn))
        #expect(up.flags.contains(.maskCommand))
    }

    @Test func functionKeysProduceAppKitFunctionCharacters() throws {
        let codes: [UInt16] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
        for (index, code) in codes.enumerated() {
            let event = try #require(MacKeyEvents.make(code, down: true, held: [63, 59]))
            #expect(event.type == .keyDown)
            #expect(event.flags.contains([.maskSecondaryFn, .maskControl]))
            let native = try #require(NSEvent(cgEvent: event))
            #expect(native.keyCode == code)
            #expect(native.characters?.unicodeScalars.first?.value == UInt32(NSF1FunctionKey) + UInt32(index))
            let up = try #require(MacKeyEvents.make(code, down: false, held: [63]))
            #expect(up.type == .keyUp && up.flags.contains(.maskSecondaryFn))
        }
    }

    @Test func fnNavigationUsesAppKitSpecialKeys() throws {
        let keys: [(UInt16, UInt32)] = [(117, UInt32(NSDeleteFunctionKey)),
            (115, UInt32(NSHomeFunctionKey)), (119, UInt32(NSEndFunctionKey)),
            (116, UInt32(NSPageUpFunctionKey)), (121, UInt32(NSPageDownFunctionKey)),
            (76, UInt32(NSEnterCharacter))]
        for (code, character) in keys {
            let event = try #require(MacKeyEvents.make(code, down: true, held: [63]))
            let native = try #require(NSEvent(cgEvent: event))
            #expect(native.characters?.unicodeScalars.first?.value == character)
            #expect(native.modifierFlags.contains(.function))
        }
    }
}
