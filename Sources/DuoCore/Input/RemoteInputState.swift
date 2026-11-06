import Foundation

public enum RemoteModifier: String, CaseIterable, Sendable {
    case control, option, shift, command, function
    public var keyCode: UInt16 {
        switch self { case .command: return 55; case .shift: return 56; case .option: return 58; case .control: return 59; case .function: return 63 }
    }
}

/// Touch controls retain a normalized pointer across layout changes. Modifiers
/// are one-shot; a drag holds the button until Drop or an explicit cancellation.
public struct RemoteInputState: Equatable, Sendable {
    public private(set) var x = 0.5
    public private(set) var y = 0.5
    public private(set) var isDragging = false
    public private(set) var isScrolling = false
    public private(set) var modifiers = Set<RemoteModifier>()
    public init() {}

    public mutating func toggleModifier(_ modifier: RemoteModifier) -> [InputEvent] {
        if modifiers.remove(modifier) != nil { return [InputEvent(.keyUp, keyCode:modifier.keyCode)] }
        modifiers.insert(modifier)
        return [InputEvent(.keyDown, keyCode:modifier.keyCode)]
    }
    public mutating func press(_ key: UInt16) -> [InputEvent] {
        let code = effectiveKey(key)
        return [InputEvent(.keyDown,keyCode:code), InputEvent(.keyUp,keyCode:code)] + releaseModifiers()
    }
    private func effectiveKey(_ key: UInt16) -> UInt16 {
        guard modifiers.contains(.function) else { return key }
        if key == 51 { return 117 } // Fn-Delete is forward delete.
        if key == 36 { return 76 } // Fn-Return is keypad Enter.
        // Preserve the arrow for system/app chords such as Fn-Control-Left.
        guard modifiers.isDisjoint(with: [.command, .control, .option]) else { return key }
        switch key {
        case 123: return 115 // Home
        case 124: return 119 // End
        case 126: return 116 // Page Up
        case 125: return 121 // Page Down
        default: return key
        }
    }
    public mutating func type(_ text: String) -> [InputEvent] {
        guard !text.isEmpty else { return [] }
        if !modifiers.isEmpty, text.count == 1, let key = Self.keyCode(for:text) { return press(key) }
        // Composed Unicode is text, not a guessed physical keyboard shortcut.
        return releaseModifiers() + [InputEvent(.text,text:text)]
    }
    public mutating func click(right: Bool = false, count: Int = 1) -> [InputEvent] {
        if isDragging { return endDrag() }
        if right { return [InputEvent(.rightClick,x:x,y:y)] + releaseModifiers() }
        let clickCount=min(2,max(1,count))
        return [InputEvent(.leftDown,x:x,y:y,clickCount:clickCount),InputEvent(.leftUp,x:x,y:y,clickCount:clickCount)] + releaseModifiers()
    }
    public mutating func finishScroll() -> [InputEvent] { isDragging ? [] : releaseModifiers() }
    public mutating func finishNativeTouch() -> [InputEvent] { isDragging ? [] : releaseModifiers() }
    public mutating func beginDrag() -> [InputEvent] {
        guard !isDragging else { return [] }
        isDragging=true; isScrolling=false
        return [InputEvent(.leftDown,x:x,y:y)]
    }
    public mutating func endDrag() -> [InputEvent] {
        guard isDragging else { return [] }
        isDragging=false
        return [InputEvent(.leftUp,x:x,y:y)] + releaseModifiers()
    }
    public mutating func toggleScroll() -> [InputEvent] {
        let release=endDrag(); isScrolling.toggle(); return release
    }
    public mutating func move(dx: Double, dy: Double, width: Double, height: Double) -> [InputEvent] {
        guard dx.isFinite,dy.isFinite,width.isFinite,height.isFinite,width>0,height>0 else { return [] }
        if isScrolling { return scroll(dx:dx,dy:dy) }
        x=min(1,max(0,x+dx/width)); y=min(1,max(0,y+dy/height))
        return [InputEvent(.move,x:x,y:y)]
    }
    public mutating func move(toX x: Double, y: Double) -> [InputEvent] {
        guard x.isFinite, y.isFinite else { return [] }
        self.x = min(1, max(0, x)); self.y = min(1, max(0, y))
        return [InputEvent(.move, x: self.x, y: self.y)]
    }
    public mutating func rememberPosition(x: Double, y: Double) {
        guard x.isFinite, y.isFinite else { return }
        self.x = min(1, max(0, x)); self.y = min(1, max(0, y))
    }
    public func scroll(dx: Double, dy: Double) -> [InputEvent] {
        guard dx.isFinite,dy.isFinite else { return [] }
        return [InputEvent(.scroll,x:min(100,max(-100,dx)),y:min(100,max(-100,dy)))]
    }
    public mutating func releaseAll() -> [InputEvent] {
        isDragging=false; isScrolling=false; modifiers.removeAll()
        return [InputEvent(.releaseAll)]
    }
    private mutating func releaseModifiers() -> [InputEvent] {
        let events = RemoteModifier.allCases.filter { modifiers.contains($0) }.map { InputEvent(.keyUp,keyCode:$0.keyCode) }
        modifiers.removeAll(); return events
    }
    /// macOS ANSI virtual key positions for explicit one-shot shortcuts.
    public static func keyCode(for text: String) -> UInt16? {
        let positions: [String:UInt16] = ["a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,"q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"1":18,"2":19,"3":20,"4":21,"6":22,"5":23,"=":24,"9":25,"7":26,"-":27,"8":28,"0":29,
            "]":30,"o":31,"u":32,"[":33,"i":34,"p":35,"l":37,"j":38,"'":39,"k":40,";":41,"\\":42,",":43,"/":44,"n":45,"m":46,".":47,"`":50," ":49]
        return positions[text.lowercased()]
    }
}
