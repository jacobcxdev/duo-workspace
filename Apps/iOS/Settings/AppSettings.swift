import Foundation
import Observation
import DuoCore

@MainActor @Observable
final class AppSettings {
    var keepAwake: Bool { didSet { defaults.set(keepAwake, forKey: "keepAwake") } }
    var automaticReconnect: Bool { didSet { defaults.set(automaticReconnect, forKey: "automaticReconnect") } }
    var naturalScrolling: Bool { didSet { defaults.set(naturalScrolling, forKey: "naturalScrolling") } }
    var pointerSpeed: Double { didSet { defaults.set(pointerSpeed, forKey: "pointerSpeed") } }
    var pointerMode: PointerMode { didSet { defaults.set(pointerMode.rawValue, forKey: "pointerMode") } }
    var touchDoubleTapAction: TouchDoubleTapAction { didSet { defaults.set(touchDoubleTapAction.rawValue, forKey: "touchDoubleTapAction") } }
    var quality: StreamQuality { didSet { defaults.set(quality.rawValue, forKey: "streamQuality") } }
    var desktopShape: DesktopShape { didSet { defaults.set(desktopShape.rawValue, forKey: "desktopShape") } }
    var desktopSizing: DesktopSizing {
        didSet {
            defaults.set(desktopSizing.rawValue, forKey: "desktopSizing")
            if desktopSizing != oldValue { matchedDisplay = nil }
        }
    }
    var matchedDisplay: DisplayPixelSize? {
        didSet {
            if let matchedDisplay, matchedDisplay.isValid, let data = try? JSONEncoder().encode(matchedDisplay) {
                defaults.set(data, forKey: "matchedDisplay")
            } else { defaults.removeObject(forKey: "matchedDisplay") }
        }
    }
    var showHints: Bool { didSet { defaults.set(showHints, forKey: "showInputHints") } }
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        keepAwake = defaults.object(forKey: "keepAwake") as? Bool ?? true
        automaticReconnect = defaults.object(forKey: "automaticReconnect") as? Bool ?? true
        naturalScrolling = defaults.object(forKey: "naturalScrolling") as? Bool ?? true
        let savedSpeed = defaults.object(forKey: "pointerSpeed") as? Double ?? 1
        pointerSpeed = savedSpeed.isFinite ? min(2, max(0.5, savedSpeed)) : 1
        pointerMode = PointerMode(rawValue: defaults.string(forKey: "pointerMode") ?? "") ?? .trackpad
        touchDoubleTapAction = TouchDoubleTapAction(rawValue: defaults.string(forKey: "touchDoubleTapAction") ?? "") ?? .rightClick
        quality = StreamQuality(rawValue: defaults.string(forKey: "streamQuality") ?? "") ?? .balanced
        desktopShape = DesktopShape(rawValue: defaults.string(forKey: "desktopShape") ?? "") ?? .automatic
        desktopSizing = DesktopSizing(rawValue: defaults.string(forKey: "desktopSizing") ?? "") ?? .comfortable
        let savedDisplay = defaults.data(forKey: "matchedDisplay").flatMap { try? JSONDecoder().decode(DisplayPixelSize.self, from: $0) }
        matchedDisplay = savedDisplay?.isValid == true ? savedDisplay : nil
        showHints = defaults.object(forKey: "showInputHints") as? Bool ?? true
    }
}
