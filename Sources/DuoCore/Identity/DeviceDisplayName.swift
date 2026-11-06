import Foundation

/// Bound both displayed characters and encoded size. A single grapheme can
/// otherwise contain thousands of combining scalars and bloat the trust store.
public enum DeviceDisplayName {
    public static func isValid(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.count <= 80 && value.utf8.count <= 512
            && value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
}
