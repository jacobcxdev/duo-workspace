import CoreGraphics
import Testing
@testable import DuoHost

struct RemotePointerLocationTests {
    @Test func boundaryCannotMovePointerOntoNeighbouringDisplay() {
        for bounds in [CGRect(x: 0, y: 0, width: 1920, height: 1080),
                       CGRect(x: -1600, y: -1200, width: 1600, height: 1200)] {
            #expect(RemotePointerLocation.point(x: 0, y: 0, in: bounds) == bounds.origin)
            #expect(RemotePointerLocation.point(x: 0.5, y: 0.5, in: bounds) == CGPoint(x: bounds.midX, y: bounds.midY))
            let edge = RemotePointerLocation.point(x: 1, y: 1, in: bounds)
            #expect(bounds.contains(edge))
            #expect(edge.x == bounds.maxX - 1 && edge.y == bounds.maxY - 1)
        }
    }
}
