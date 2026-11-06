import Foundation
import DuoCore

extension DesktopSizing {
    var title: LocalizedStringResource {
        switch self {
        case .comfortable: "Comfortable"
        case .moreSpace: "More space"
        case .matchDisplay: "Match display"
        }
    }
    var explanation: LocalizedStringResource {
        switch self {
        case .comfortable: "Larger Mac text and a smaller workspace."
        case .moreSpace: "Fits more Mac windows, with smaller text."
        case .matchDisplay: "Uses this display's native pixels. Mac text can be smaller."
        }
    }
}
