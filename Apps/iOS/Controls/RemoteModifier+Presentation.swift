import Foundation
import DuoCore

extension RemoteModifier {
    var glyph: String {
        switch self {
        case .command: "⌘"
        case .shift: "⇧"
        case .option: "⌥"
        case .control: "⌃"
        case .function: "Fn"
        }
    }

    var name: LocalizedStringResource {
        switch self {
        case .command: "Command"
        case .option: "Option"
        case .shift: "Shift"
        case .control: "Control"
        case .function: "Fn"
        }
    }
}
