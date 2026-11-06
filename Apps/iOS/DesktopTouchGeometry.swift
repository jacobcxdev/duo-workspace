import CoreGraphics

/// Matches the centered aspect-fit video. Empty margins aren't Mac coordinates.
enum DesktopTouchGeometry {
    static func imageRect(in bounds: CGRect, aspect: Double) -> CGRect? {
        guard bounds.width.isFinite, bounds.height.isFinite, bounds.minX.isFinite, bounds.minY.isFinite,
              bounds.width > 0, bounds.height > 0, aspect.isFinite, aspect > 0 else { return nil }
        let width = min(bounds.width, bounds.height * aspect)
        let height = width / aspect
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
        return CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
    }

    static func normalized(_ point: CGPoint, in bounds: CGRect, aspect: Double, clamped: Bool = false) -> CGPoint? {
        guard point.x.isFinite, point.y.isFinite, let image = imageRect(in: bounds, aspect: aspect) else { return nil }
        let x = (point.x - image.minX) / image.width
        let y = (point.y - image.minY) / image.height
        guard clamped || ((0...1).contains(x) && (0...1).contains(y)) else { return nil }
        return CGPoint(x: min(1, max(0, x)), y: min(1, max(0, y)))
    }
}
