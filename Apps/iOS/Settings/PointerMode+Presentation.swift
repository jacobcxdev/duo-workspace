import Foundation
import DuoCore

extension PointerMode {
    var title: LocalizedStringResource {
        switch self {
        case .trackpad: "Trackpad"
        case .direct: "Touch"
        case .nativeTouch: "Native touch"
        }
    }
}
