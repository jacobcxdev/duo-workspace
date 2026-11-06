import Foundation

enum KeyboardPresentation: Equatable {
    case hidden, accessory, software

    var hasKeyboardUI: Bool { self != .hidden }
    var hasSoftwareKeys: Bool { self == .software }

    func forSession(keyboardMode: Bool, focusRequested: Bool) -> Self {
        keyboardMode && focusRequested ? self : .hidden
    }

    static func measured(occupiedHeight: CGFloat, accessoryHeight: CGFloat) -> Self {
        guard occupiedHeight > 1 else { return .hidden }
        return occupiedHeight > accessoryHeight + 1 ? .software : .accessory
    }
}
