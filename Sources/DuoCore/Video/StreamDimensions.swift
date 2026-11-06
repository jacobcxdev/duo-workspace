import Foundation

public struct StreamDimensions: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public static func forDesktop(_ desktop: DesktopSize, quality: StreamQuality) -> StreamDimensions {
        guard desktop.isValid else { return StreamDimensions(width: quality.width, height: quality.height) }
        return forSource(width: desktop.width * desktop.scale, height: desktop.height * desktop.scale, quality: quality)
    }
    public static func forSource(width sourceWidth: Int, height sourceHeight: Int, quality: StreamQuality) -> StreamDimensions {
        guard sourceWidth > 0, sourceHeight > 0, sourceWidth <= 16_384, sourceHeight <= 16_384 else {
            return StreamDimensions(width: quality.width, height: quality.height)
        }
        let width = Double(sourceWidth), height = Double(sourceHeight)
        let budget = Double(min(quality.width * quality.height, VideoRasterLimits.maximumPixels))
        let axis = Double(VideoRasterLimits.maximumAxis)
        let factor = min(1, sqrt(budget / (width * height)), axis / width, axis / height)
        return StreamDimensions(width: max(2, Int(width * factor / 2) * 2), height: max(2, Int(height * factor / 2) * 2))
    }
}
