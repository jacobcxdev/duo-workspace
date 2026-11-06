import CoreGraphics

enum RemotePointerLocation {
    static func point(x: Double, y: Double, in bounds: CGRect) -> CGPoint {
        // The maximum edge is outside this display. Keep a drag at the video
        // boundary inside the selected Mac display.
        CGPoint(x: bounds.minX + min(max(0, bounds.width - 1), max(0, x * bounds.width)),
                y: bounds.minY + min(max(0, bounds.height - 1), max(0, y * bounds.height)))
    }
}
