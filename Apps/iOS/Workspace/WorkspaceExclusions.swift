import SwiftUI

enum WorkspaceExclusions {
    static func rects(in geometry: GeometryProxy, direction: LayoutDirection, spacing: CGFloat = 8) -> [CGRect] {
        guard #available(iOS 27.1, *) else { return [] }
        return (geometry.reservedRegions(kind: .occlusion, layoutDirectionBehavior: .fixed)
                + geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed))
            .filter(\.isActive).map { region in
                let left = direction == .rightToLeft ? region.margins.trailing : region.margins.leading
                return CGRect(x: region.frame.minX - left - spacing, y: region.frame.minY - region.margins.top - spacing,
                              width: region.frame.width + region.margins.leading + region.margins.trailing + spacing * 2,
                              height: region.frame.height + region.margins.top + region.margins.bottom + spacing * 2)
            }
    }
}
