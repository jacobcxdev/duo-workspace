import UIKit

extension MacFunctionKey {
    var commandInput: String? {
        switch self {
        case .up: UIKeyCommand.inputUpArrow
        case .down: UIKeyCommand.inputDownArrow
        case .left: UIKeyCommand.inputLeftArrow
        case .right: UIKeyCommand.inputRightArrow
        case .escape: UIKeyCommand.inputEscape
        case .tab: "\t"
        default: nil
        }
    }

    static func from(_ usage: UIKeyboardHIDUsage) -> Self? {
        switch usage {
        case .keyboardF1: .f1
        case .keyboardF2: .f2
        case .keyboardF3: .f3
        case .keyboardF4: .f4
        case .keyboardF5: .f5
        case .keyboardF6: .f6
        case .keyboardF7: .f7
        case .keyboardF8: .f8
        case .keyboardF9: .f9
        case .keyboardF10: .f10
        case .keyboardF11: .f11
        case .keyboardF12: .f12
        default: nil
        }
    }
}
