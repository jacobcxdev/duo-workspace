import Foundation
import Testing
@testable import DuoWorkspace
import DuoCore

@MainActor struct ClientBehaviorTests {
    @Test func editsExistingHostWithoutReplacingItsKey() throws {
        let name = "DuoTest.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let host = HostProfile(name: "Old name", address: "mac.local")
        defaults.set(try JSONEncoder().encode([host]), forKey: "DuoHosts")
        let model = SessionModel(defaults: defaults)
        try model.library.update(id: host.id, name: "Office", address: " MAC.local ", port: 47991, mode: .extend)
        let restored = SessionModel(defaults: defaults)
        #expect(restored.library.hosts.count == 1)
        #expect(restored.library.hosts.first?.name == "Office")
        #expect(restored.library.hosts.first?.address == "mac.local")
        #expect(restored.library.hosts.first?.mode == .extend)
        #expect(restored.library.hosts.first?.id == host.id)
    }

    @Test func missingPairingShowsRecoveryAndNeverEnablesInput() throws {
        let name = "DuoTest.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = SessionModel(defaults: defaults)
        model.connect(HostProfile(name: "Unpaired test Mac", address: "127.0.0.1"))
        #expect(model.presentsSession)
        #expect(!model.canControl)
        #expect(!model.hasVideo)
        if case .failed = model.state {} else { Issue.record("Missing key must fail visibly") }
        model.settings.quality = .efficient
        model.reconnect()
        #expect(model.display.quality == .efficient)
        model.disconnect()
        #expect(!model.presentsSession)
        #expect(model.active == nil)
    }

    @Test func settingsPersistAndClampInvalidSpeed() throws {
        let name = "DuoTest.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Double.nan, forKey: "pointerSpeed")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.pointerSpeed == 1)
        #expect(settings.pointerMode == .trackpad)
        #expect(settings.touchDoubleTapAction == .rightClick)
        settings.pointerMode = .direct
        settings.touchDoubleTapAction = .doubleClick
        #expect(settings.desktopShape == .automatic)
        settings.quality = .sharp
        settings.desktopShape = .portrait3x4
        settings.desktopSizing = .matchDisplay
        settings.matchedDisplay = DisplayPixelSize(width: 2007, height: 2853)
        settings.keepAwake = false
        settings.naturalScrolling = false
        let restored = AppSettings(defaults: defaults)
        #expect(restored.pointerMode == .direct)
        #expect(restored.touchDoubleTapAction == .doubleClick)
        #expect(restored.quality == .sharp)
        #expect(restored.desktopShape == .portrait3x4)
        #expect(restored.desktopSizing == .matchDisplay)
        #expect(restored.matchedDisplay == DisplayPixelSize(width: 2007, height: 2853))
        #expect(!restored.keepAwake)
        #expect(!restored.naturalScrolling)
        defaults.set("unknown-shape", forKey: "desktopShape")
        #expect(AppSettings(defaults: defaults).desktopShape == .automatic)
        defaults.set("unknown-mode", forKey: "pointerMode")
        defaults.set("unknown-action", forKey: "touchDoubleTapAction")
        #expect(AppSettings(defaults: defaults).pointerMode == .trackpad)
        #expect(AppSettings(defaults: defaults).touchDoubleTapAction == .rightClick)
    }

    @Test func pointerPreferencesChangeTransmittedInput() throws {
        let name = "DuoTest.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        let input = SessionInputController(settings: settings)
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        settings.pointerSpeed = 2
        input.move(CGPoint(x: 10, y: 10), in: CGSize(width: 100, height: 100))
        #expect(events.last?.x == 0.7)
        settings.naturalScrolling = false
        input.scroll(CGPoint(x: 5, y: 10))
        #expect(events.last?.y == -10)
    }

    @Test func largeUnicodePasteIsLosslessAndBounded() throws {
        let name = "DuoTest.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        let text = String(repeating: "café 日本語 😀 ", count: 1000)
        input.type(text)
        #expect(events.allSatisfy { $0.isValid })
        #expect(events.compactMap(\.text).joined() == text)
    }

    @Test func hardwareShortcutAndReleaseClearModifiers() throws {
        let name = "DuoTest.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let input = SessionInputController(settings: AppSettings(defaults: defaults))
        var events: [InputEvent] = []
        input.emit = { events.append($0) }
        input.hardwareKey(123, modifiers: [.command, .shift])
        #expect(events.contains { $0.kind == .keyDown && $0.keyCode == 55 })
        #expect(events.contains { $0.kind == .keyDown && $0.keyCode == 56 })
        #expect(input.modifiers.isEmpty)
        input.beginDrag()
        input.releaseAll()
        #expect(!input.isDragging)
        #expect(events.last?.kind == .releaseAll)
    }
}
