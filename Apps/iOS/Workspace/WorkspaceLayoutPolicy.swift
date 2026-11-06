import Foundation

enum WorkspaceLayoutPolicy {
    static func usesTabletopPanes(division: CGRect?, keyboardMode: Bool, softwareKeyboardVisible: Bool, inputEnabled: Bool = true, controlsVisible: Bool = true,
                                  lowerPaneCanFitControls: Bool = true) -> Bool {
        guard inputEnabled, let division, division.width > division.height else { return false }
        return (keyboardMode && softwareKeyboardVisible)
            || ((controlsVisible || keyboardMode) && lowerPaneCanFitControls)
    }

    static func showsTabletopTrackpad(availableHeight: CGFloat, minimumHeight: CGFloat) -> Bool {
        availableHeight.isFinite && minimumHeight.isFinite
            && minimumHeight > 0 && availableHeight >= minimumHeight
    }
}
