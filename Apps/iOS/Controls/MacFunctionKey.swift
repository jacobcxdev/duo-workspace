import Foundation

enum MacFunctionKey: CaseIterable, Identifiable {
    case escape, tab, delete, enter, left, down, up, right
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

    static let editingKeys: [Self] = [.escape, .tab, .delete, .enter, .left, .down, .up, .right]
    static let functionKeys: [Self] = [.f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12]

    var id: UInt16 { code }
    var code: UInt16 {
        switch self {
        case .escape: 53
        case .tab: 48
        case .delete: 51
        case .enter: 36
        case .left: 123
        case .down: 125
        case .up: 126
        case .right: 124
        case .f1: 122
        case .f2: 120
        case .f3: 99
        case .f4: 118
        case .f5: 96
        case .f6: 97
        case .f7: 98
        case .f8: 100
        case .f9: 101
        case .f10: 109
        case .f11: 103
        case .f12: 111
        }
    }
    var glyph: String {
        switch self {
        case .escape: "Esc"
        case .tab: "Tab"
        case .delete: "⌫"
        case .enter: "↩"
        case .left: "←"
        case .down: "↓"
        case .up: "↑"
        case .right: "→"
        case .f1: "F1"
        case .f2: "F2"
        case .f3: "F3"
        case .f4: "F4"
        case .f5: "F5"
        case .f6: "F6"
        case .f7: "F7"
        case .f8: "F8"
        case .f9: "F9"
        case .f10: "F10"
        case .f11: "F11"
        case .f12: "F12"
        }
    }
    var name: LocalizedStringResource {
        switch self {
        case .escape: "Escape"
        case .tab: "Tab"
        case .delete: "Delete"
        case .enter: "Return"
        case .left: "Left arrow"
        case .down: "Down arrow"
        case .up: "Up arrow"
        case .right: "Right arrow"
        case .f1: "F1"
        case .f2: "F2"
        case .f3: "F3"
        case .f4: "F4"
        case .f5: "F5"
        case .f6: "F6"
        case .f7: "F7"
        case .f8: "F8"
        case .f9: "F9"
        case .f10: "F10"
        case .f11: "F11"
        case .f12: "F12"
        }
    }
}
