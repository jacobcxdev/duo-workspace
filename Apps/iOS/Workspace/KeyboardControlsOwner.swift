import Foundation

enum KeyboardControlsOwner: Equatable {
    case inputAccessory
    case workspace

    func hasVisibleAccessory(for presentation: KeyboardPresentation) -> Bool {
        self == .inputAccessory && presentation.hasKeyboardUI
    }

    func forKeyboard(language: String?, hasComposedText: Bool) -> Self {
        // Other input modes need this margin for their candidate strip.
        guard self == .workspace, !hasComposedText,
              language?.split(separator: "-").first?.lowercased() == "en" else { return .inputAccessory }
        return .workspace
    }

    static func preferred(division: CGRect?, lowerPaneCanFitControls: Bool,
                          inputEnabled: Bool, prefersNativeAccessibility: Bool) -> Self {
        guard inputEnabled, !prefersNativeAccessibility, lowerPaneCanFitControls,
              let division, division.width > division.height else { return .inputAccessory }
        return .workspace
    }
}
