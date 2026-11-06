import Foundation

enum TouchDoubleTapAction: String, CaseIterable {
    case rightClick, doubleClick

    var title: LocalizedStringResource {
        switch self {
        case .rightClick: "Right-click"
        case .doubleClick: "Double-click"
        }
    }
}
