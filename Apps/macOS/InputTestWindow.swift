#if DEBUG
import AppKit

/// Records input received by this test window only.
@MainActor final class InputTestWindow {
    static let shared = InputTestWindow()
    private var window: NSWindow?

    func show(displayID: CGDirectDisplayID) {
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? NSRect(x: 100, y: 100, width: 700, height: 450)
        let window = self.window ?? NSWindow(contentRect: frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        if self.window == nil { window.contentView = InputTestView(); window.isReleasedWhenClosed = false }
        self.window = window
        window.title = "Duo Workspace: Input test"
        window.setFrame(frame.insetBy(dx: 24, dy: 24), display: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private final class InputTestView:NSView {
    private var clicks=0, releases=0, drags=0, scrolls=0, rightClicks=0
    private var buttonHeld=false
    private var keysDown=Set<UInt16>()
    private var modifiers=NSEvent.ModifierFlags()
    private var lastKeyFlags="None"
    private var lastKeyCode: UInt16?
    private var received=""
    private var lastEvent="Waiting for input"
    override init(frame:NSRect) {super.init(frame:frame);setAccessibilityElement(true);setAccessibilityRole(.staticText);updateAccessibility()}
    required init?(coder:NSCoder) {fatalError()}
    override var acceptsFirstResponder:Bool {true}
    override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
    override var isFlipped:Bool {true}
    private func names(_ flags:NSEvent.ModifierFlags)->String {
        let pairs:[(NSEvent.ModifierFlags,String)]=[(.command,"Command"),(.shift,"Shift"),(.option,"Option"),(.control,"Control"),(.function,"Fn")]
        let names=pairs.filter {flags.contains($0.0)}.map {$0.1}
        return names.isEmpty ? "None":names.joined(separator:" + ")
    }
    private var summary:String {
        """
        Duo Workspace input test

        Clicks: \(clicks)    Releases: \(releases)    Right clicks: \(rightClicks)
        Drag events: \(drags)    Scroll events: \(scrolls)
        Held keys: \(keysDown.count)    Mouse held: \(buttonHeld ? "Yes":"No")
        Modifiers: \(names(modifiers))
        Last key modifiers: \(lastKeyFlags)
        Last key code: \(lastKeyCode.map(String.init) ?? "None")
        Last event: \(lastEvent)

        Received text:
        \(received)

        Use the simulator trackpad, Drag / Drop, Scroll and modifier controls.
        Closing a panel or disconnecting must release every key and button.
        """
    }
    private func updateAccessibility() {setAccessibilityLabel("Mac input test results");setAccessibilityValue(summary)}
    private func changed() {needsDisplay=true;updateAccessibility();NSAccessibility.post(element:self,notification:.valueChanged)}
    override func draw(_ dirtyRect:NSRect) {
        NSColor.windowBackgroundColor.setFill();bounds.fill()
        (summary as NSString).draw(in:bounds.insetBy(dx:24,dy:24),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:16,weight:.regular),.foregroundColor:NSColor.labelColor])
    }
    override func mouseDown(with event:NSEvent) {clicks += 1;buttonHeld=true;lastEvent="Mouse down";changed()}
    override func mouseUp(with event:NSEvent) {releases += 1;buttonHeld=false;lastEvent="Mouse up";changed()}
    override func mouseDragged(with event:NSEvent) {drags += 1;lastEvent="Drag";changed()}
    override func rightMouseDown(with event:NSEvent) {rightClicks += 1;lastEvent="Right click";changed()}
    override func scrollWheel(with event:NSEvent) {scrolls += 1;lastEvent="Scroll";changed()}
    override func flagsChanged(with event:NSEvent) {modifiers=event.modifierFlags.intersection([.command,.shift,.option,.control,.function]);lastEvent="Modifier change";changed()}
    override func keyDown(with event:NSEvent) {
        keysDown.insert(event.keyCode);lastKeyFlags=names(event.modifierFlags)
        lastKeyCode=event.keyCode
        if let text=event.characters {received += text;received=String(received.suffix(500))}
        lastEvent="Key down \(event.keyCode)";changed()
    }
    override func keyUp(with event:NSEvent) {keysDown.remove(event.keyCode);lastEvent="Key up \(event.keyCode)";changed()}
    override func performKeyEquivalent(with event:NSEvent)->Bool {
        if event.modifierFlags.contains(.command),[UInt16(0),6,8,9].contains(event.keyCode) {lastKeyFlags=names(event.modifierFlags);lastEvent="Shortcut \(event.keyCode)";changed();return true}
        return super.performKeyEquivalent(with:event)
    }
}
#endif
