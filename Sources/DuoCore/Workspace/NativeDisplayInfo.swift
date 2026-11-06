import Foundation

public struct NativeDisplayInfo: Equatable, Sendable {
    public let pixels: DisplayPixelSize
    public let pointWidth: Double
    public let pointHeight: Double
    public let nativeScale: Double

    public init(pixels: DisplayPixelSize, pointWidth: Double, pointHeight: Double, nativeScale: Double) {
        self.pixels = pixels; self.pointWidth = pointWidth; self.pointHeight = pointHeight; self.nativeScale = nativeScale
    }

    public var isValid: Bool {
        pixels.isValid && pointWidth.isFinite && pointHeight.isFinite && nativeScale.isFinite
            && (80...16_384).contains(pointWidth) && (80...16_384).contains(pointHeight) && (0.5...8).contains(nativeScale)
    }

    public func pixels(viewportWidth: Double, viewportHeight: Double) -> DisplayPixelSize? {
        guard isValid, viewportWidth.isFinite, viewportHeight.isFinite,
              (80...16_384).contains(viewportWidth), (80...16_384).contains(viewportHeight) else { return nil }
        // Full-screen points can be rounded by Display Zoom. Use the panel's
        // exact pixel pair there; smaller media regions use the native scale.
        if min(viewportWidth, viewportHeight) == min(pointWidth, pointHeight),
           max(viewportWidth, viewportHeight) == max(pointWidth, pointHeight) {
            let long = max(pixels.width, pixels.height), short = min(pixels.width, pixels.height)
            return viewportWidth >= viewportHeight ? DisplayPixelSize(width: long, height: short) : DisplayPixelSize(width: short, height: long)
        }
        let width = (viewportWidth * nativeScale).rounded(), height = (viewportHeight * nativeScale).rounded()
        guard width <= 16_384, height <= 16_384 else { return nil }
        return DisplayPixelSize(width: Int(width), height: Int(height))
    }
}
