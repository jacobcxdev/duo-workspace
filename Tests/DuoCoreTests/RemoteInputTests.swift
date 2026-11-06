import XCTest
@testable import DuoCore

final class RemoteInputTests: XCTestCase {
    func testAbsoluteMovementKeepsDragStateAndRejectsInvalidPoints() {
        var state = RemoteInputState()
        _ = state.beginDrag()
        let events = state.move(toX: 0.2, y: 0.8)
        XCTAssertEqual(events.map(\.kind), [.move])
        XCTAssertEqual(state.x, 0.2); XCTAssertEqual(state.y, 0.8)
        XCTAssertTrue(state.isDragging)
        XCTAssertTrue(state.move(toX: .nan, y: 0).isEmpty)
        XCTAssertTrue(state.move(toX: 0, y: .infinity).isEmpty)
        XCTAssertEqual(state.x, 0.2); XCTAssertEqual(state.y, 0.8)
        _ = state.move(toX: 4, y: -2)
        XCTAssertEqual(state.x, 1); XCTAssertEqual(state.y, 0)
        XCTAssertEqual(state.endDrag().first?.kind, .leftUp)
    }
    func testDragKeepsButtonDownUntilDropAndReleasesModifiers() {
        var state=RemoteInputState()
        _=state.toggleModifier(.shift)
        XCTAssertEqual(state.beginDrag().map(\.kind),[.leftDown])
        XCTAssertEqual(state.move(dx:100,dy:-100,width:200,height:200).map(\.kind),[.move])
        XCTAssertTrue(state.isDragging);XCTAssertEqual(state.x,1);XCTAssertEqual(state.y,0)
        XCTAssertEqual(state.endDrag().map(\.kind),[.leftUp,.keyUp])
        XCTAssertFalse(state.isDragging);XCTAssertTrue(state.modifiers.isEmpty)
    }
    func testScrollModeEndsDragAndDoesNotMovePointer() {
        var state=RemoteInputState();_=state.beginDrag()
        XCTAssertEqual(state.toggleScroll().first?.kind,.leftUp)
        let event=state.move(dx:200,dy:-200,width:100,height:100).first!
        XCTAssertEqual(event.kind,.scroll);XCTAssertEqual(event.x,100);XCTAssertEqual(event.y,-100)
        XCTAssertEqual(state.x,0.5);XCTAssertEqual(state.y,0.5)
        XCTAssertTrue(event.isValid)
    }
    func testCommandShortcutUsesCorrectPhysicalKeyThenReleasesCommand() {
        var state=RemoteInputState();_=state.toggleModifier(.command)
        let events=state.type("c")
        XCTAssertEqual(events.map(\.kind),[.keyDown,.keyUp,.keyUp])
        XCTAssertEqual(events.map(\.keyCode),[8,8,55])
        XCTAssertTrue(state.modifiers.isEmpty)
    }
    func testUnicodeDoesNotBecomeAShortcutAndResetCancelsHeldState() {
        var state=RemoteInputState();_=state.toggleModifier(.option)
        let events=state.type("日本語 😀")
        XCTAssertEqual(events.map(\.kind),[.keyUp,.text]);XCTAssertEqual(events.last?.text,"日本語 😀")
        _=state.toggleModifier(.command);_=state.beginDrag()
        XCTAssertEqual(state.releaseAll().map(\.kind),[.releaseAll])
        XCTAssertTrue(state.modifiers.isEmpty);XCTAssertFalse(state.isDragging)
    }
    func testDoubleClickAndInvalidMovement() {
        var state=RemoteInputState()
        let clicks=state.click()+state.click(count:2)
        XCTAssertEqual(clicks.map(\.clickCount),[1,1,2,2])
        XCTAssertTrue(state.move(dx:.nan,dy:0,width:100,height:100).isEmpty)
        XCTAssertFalse(InputEvent(.leftDown,x:0,y:0,clickCount:3).isValid)
    }
}
