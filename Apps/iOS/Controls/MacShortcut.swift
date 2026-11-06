import Foundation

enum MacShortcut: UInt16, CaseIterable, Identifiable {
    case selectAll = 0, copy = 8, paste = 9, cut = 7, undo = 6

    static let menuItems: [Self] = [.selectAll, .copy, .paste, .undo]
    var id: UInt16 { rawValue }
    var keyCode: UInt16 { rawValue }

    var input: String {
        switch self {
        case .selectAll: "a"
        case .copy: "c"
        case .paste: "v"
        case .cut: "x"
        case .undo: "z"
        }
    }

    var name: LocalizedStringResource {
        switch self {
        case .selectAll: "Select all on Mac"
        case .copy: "Copy on Mac"
        case .paste: "Paste on Mac"
        case .cut: "Cut on Mac"
        case .undo: "Undo on Mac"
        }
    }
}
