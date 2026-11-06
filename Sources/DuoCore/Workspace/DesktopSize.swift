import Foundation

public struct DesktopSize: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let scale: Int
    public init(width: Int, height: Int, scale: Int = 2) { self.width = width; self.height = height; self.scale = scale }
    public var isValid: Bool {
        (320...2048).contains(width) && (240...2048).contains(height)
            && width % 2 == 0 && height % 2 == 0 && width * height <= 2_097_152 && (scale == 1 || scale == 2)
    }
    public static func viewport(width: Double, height: Double) -> DesktopSize? {
        guard width.isFinite, height.isFinite, width >= 80, height >= 80 else { return nil }
        // WindowServer rejects smaller HiDPI modes. Scale both axes together
        // to meet these limits without changing the aspect ratio.
        let minimum = max(526 / min(width, height), 800 / max(width, height))
        let maximum = min(2048 / width, 2048 / height, sqrt(2_097_152 / (width * height)))
        guard minimum <= maximum else { return nil }
        let factor = min(max(1, minimum), maximum)
        let value = DesktopSize(width: max(width >= height ? 800 : 526, Int((width * factor / 2).rounded(.down)) * 2),
                                height: max(height >= width ? 800 : 526, Int((height * factor / 2).rounded(.down)) * 2))
        return value.isValid ? value : nil
    }
}
