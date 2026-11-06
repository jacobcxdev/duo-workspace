public enum DesktopShape: String, CaseIterable, Sendable {
    case automatic
    case landscape16x10 = "16:10"
    case landscape16x9 = "16:9"
    case landscape4x3 = "4:3"
    case ultrawide = "21:9"
    case portrait3x4 = "3:4"
    case portrait10x16 = "10:16"
    case portrait9x16 = "9:16"
    case square = "1:1"

    public var fixedSize: DesktopSize? {
        switch self {
        case .automatic: nil
        case .landscape16x10: DesktopSize(width: 960, height: 600)
        case .landscape16x9: DesktopSize(width: 960, height: 540)
        case .landscape4x3: DesktopSize(width: 800, height: 600)
        case .ultrawide: DesktopSize(width: 1260, height: 540)
        case .portrait3x4: DesktopSize(width: 600, height: 800)
        case .portrait10x16: DesktopSize(width: 600, height: 960)
        case .portrait9x16: DesktopSize(width: 540, height: 960)
        case .square: DesktopSize(width: 800, height: 800)
        }
    }

    public func desktop(viewportWidth: Double, viewportHeight: Double) -> DesktopSize? {
        guard viewportWidth.isFinite, viewportHeight.isFinite, viewportWidth >= 80, viewportHeight >= 80 else { return nil }
        return fixedSize ?? DesktopSize.viewport(width: viewportWidth, height: viewportHeight)
    }

    public var aspectRatio: Double? {
        switch self {
        case .automatic: nil
        case .landscape16x10: 16.0 / 10
        case .landscape16x9: 16.0 / 9
        case .landscape4x3: 4.0 / 3
        case .ultrawide: 21.0 / 9
        case .portrait3x4: 3.0 / 4
        case .portrait10x16: 10.0 / 16
        case .portrait9x16: 9.0 / 16
        case .square: 1
        }
    }
}
