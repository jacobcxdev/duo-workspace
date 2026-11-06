public enum DesktopSizing: String, CaseIterable, Sendable {
    case comfortable, moreSpace, matchDisplay

    public func desktop(shape: DesktopShape, viewportWidth: Double, viewportHeight: Double,
                        display: NativeDisplayInfo? = nil, matchedDisplay: DisplayPixelSize? = nil) -> DesktopSize? {
        guard viewportWidth.isFinite, viewportHeight.isFinite, viewportWidth >= 80, viewportHeight >= 80 else { return nil }
        switch self {
        case .comfortable:
            return shape.desktop(viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        case .moreSpace:
            guard let base = shape.desktop(viewportWidth: viewportWidth, viewportHeight: viewportHeight) else { return nil }
            return DesktopSize.viewport(width: Double(base.width) * 1.5, height: Double(base.height) * 1.5)
        case .matchDisplay:
            if let ratio = shape.aspectRatio, let matchedDisplay, matchedDisplay.isValid {
                let long = Double(max(matchedDisplay.width, matchedDisplay.height))
                let short = Double(min(matchedDisplay.width, matchedDisplay.height))
                let availableWidth = ratio >= 1 ? long : short, availableHeight = ratio >= 1 ? short : long
                let width = min(availableWidth, availableHeight * ratio)
                return DesktopSize.viewport(width: width / 2, height: width / ratio / 2)
            }
            if shape == .automatic, let pixels = display?.pixels(viewportWidth: viewportWidth, viewportHeight: viewportHeight) {
                return DesktopSize.viewport(width: Double(pixels.width) / 2, height: Double(pixels.height) / 2)
            }
            return shape.desktop(viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        }
    }
}
