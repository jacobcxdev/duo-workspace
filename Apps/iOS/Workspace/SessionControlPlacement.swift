import Foundation

enum SessionControlPlacement {
    static func frame(in available: CGRect, size: CGSize, avoiding regions: [CGRect], trailing: Bool, preferredOrigin: CGPoint? = nil) -> CGRect? {
        guard available.width >= size.width, available.height >= size.height else { return nil }
        let maxX = available.maxX - size.width
        let maxY = available.maxY - size.height
        let preferred = preferredOrigin ?? CGPoint(x: trailing ? maxX : available.minX, y: available.minY)
        var xs = [available.minX, maxX, preferred.x]
        var ys = [available.minY, maxY, preferred.y]
        for region in regions {
            xs += [region.minX - size.width, region.maxX]
            ys += [region.minY - size.height, region.maxY]
        }
        let candidates = xs.flatMap { x in ys.map { y in
            CGRect(origin: CGPoint(x: min(max(x, available.minX), maxX), y: min(max(y, available.minY), maxY)), size: size)
        } }
        return candidates.filter { frame in !regions.contains { $0.intersects(frame) } }.min { a, b in
            let aDistance = abs(a.minY - preferred.y) + abs(a.minX - preferred.x)
            let bDistance = abs(b.minY - preferred.y) + abs(b.minX - preferred.x)
            return aDistance < bDistance
        }
    }
}
