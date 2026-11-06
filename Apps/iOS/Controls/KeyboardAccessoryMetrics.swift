import UIKit

@MainActor
enum KeyboardAccessoryMetrics {
    static let minimumHeight: CGFloat = 52

    static func height(for traits: UITraitCollection) -> CGFloat {
        max(minimumHeight, UIFontMetrics(forTextStyle: .body).scaledValue(for: minimumHeight, compatibleWith: traits))
    }
}
