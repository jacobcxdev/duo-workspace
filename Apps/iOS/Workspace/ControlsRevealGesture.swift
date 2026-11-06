import CoreGraphics

enum ControlsRevealGesture {
    static func hintFrame(in bounds: CGRect, trailing: Bool, avoiding regions: [CGRect]) -> CGRect? {
        guard bounds.width >= 20, bounds.height >= 52 else { return nil }
        let strip = CGRect(x: trailing ? bounds.maxX - 10 : bounds.minX + 6,
                           y: bounds.minY + 6, width: 4, height: bounds.height - 12)
        return SessionControlPlacement.frame(in: strip, size: CGSize(width: 4, height: 40), avoiding: regions,
                                             trailing: trailing, preferredOrigin: CGPoint(x: strip.minX, y: bounds.midY - 20))
    }

    static func startsAtEdge(_ point: CGPoint, in bounds: CGRect) -> Bool {
        guard bounds.contains(point) else { return false }
        let inset = min(24, bounds.width / 4)
        return point.x <= bounds.minX + inset || point.x >= bounds.maxX - inset
    }

    static func isInward(start: CGPoint, translation: CGPoint, in bounds: CGRect, minimumDistance: Double = 0) -> Bool {
        guard startsAtEdge(start, in: bounds), translation.x.isFinite, translation.y.isFinite,
              abs(translation.x) > abs(translation.y), abs(translation.x) >= minimumDistance else { return false }
        return start.x < bounds.midX ? translation.x > 0 : translation.x < 0
    }
}
