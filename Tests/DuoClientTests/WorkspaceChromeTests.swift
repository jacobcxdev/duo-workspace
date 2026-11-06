import CoreGraphics
import Testing
@testable import DuoWorkspace

@MainActor
struct WorkspaceChromeTests {
    @Test func hideRetainsTheControlPaneUntilTheFadeFinishes() {
        let chrome = WorkspaceChrome()
        let request = chrome.beginHiding()
        #expect(!chrome.isVisible && chrome.reservesControlPane)
        chrome.finishHiding(request: request)
        #expect(!chrome.isVisible && !chrome.reservesControlPane)
        chrome.show()
        #expect(chrome.isVisible && chrome.reservesControlPane)
    }

    @Test func reversingOrRepeatingAHideCannotApplyAnOldCompletion() {
        let chrome = WorkspaceChrome()
        let first = chrome.beginHiding()
        chrome.show()
        chrome.finishHiding(request: first)
        #expect(chrome.isVisible && chrome.reservesControlPane)
        let second = chrome.beginHiding(), third = chrome.beginHiding()
        chrome.finishHiding(request: second)
        #expect(!chrome.isVisible && chrome.reservesControlPane)
        chrome.finishHiding(request: third)
        #expect(!chrome.isVisible && !chrome.reservesControlPane)
    }

    @Test func sideHintsStayInsideTheSwipeZoneAndAvoidTheHinge() throws {
        for size in [CGSize(width: 466, height: 678), CGSize(width: 678, height: 466),
                     CGSize(width: 669, height: 951), CGSize(width: 951, height: 669)] {
            let bounds = CGRect(origin: .zero, size: size)
            let hinge = CGRect(x: 0, y: size.height / 2 - 15, width: size.width, height: 30)
            for trailing in [false, true] {
                let hint = try #require(ControlsRevealGesture.hintFrame(in: bounds, trailing: trailing, avoiding: [hinge]))
                #expect(bounds.contains(hint))
                #expect(!hint.intersects(hinge))
                #expect(ControlsRevealGesture.startsAtEdge(CGPoint(x: hint.midX, y: hint.midY), in: bounds))
            }
        }
    }

    @Test func blockedSideDoesNotMoveItsHintToAnInactiveGestureArea() {
        let bounds = CGRect(x: 0, y: 0, width: 466, height: 678)
        let bar = CGRect(x: 0, y: 0, width: 60, height: 678)
        #expect(ControlsRevealGesture.hintFrame(in: bounds, trailing: false, avoiding: [bar]) == nil)
        #expect(ControlsRevealGesture.hintFrame(in: bounds, trailing: true, avoiding: [bar]) != nil)
    }
}
