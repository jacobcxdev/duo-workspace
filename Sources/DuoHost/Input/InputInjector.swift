import Foundation
import AppKit
import CoreGraphics
import DuoCore

public final class InputInjector {
    public var displayID:CGDirectDisplayID=CGMainDisplayID()
    public var routesKeyboardToRemoteWindow=false
    var nativeTouchActive = false
    public private(set) var keyboardTargetPID:pid_t?
    private var pendingKeyboard=[CGEvent]()
    private var keyboardActivationPending=false
    private var keyboardGeneration=0
    private var held=Set<UInt16>()
    private var globalModifiers=Set<UInt16>()
    private var mouseDown=false
    private var pointerX=0.5, pointerY=0.5
    public init() {}

    func noteNativeTouch(_ contact: NativeTouchContact, selectTarget: Bool) {
        guard contact.isValid else { return }
        pointerX = contact.x; pointerY = contact.y
        if selectTarget { selectKeyboardTarget(at: pointer) }
    }

    private var pointer:CGPoint {
        RemotePointerLocation.point(x: pointerX, y: pointerY, in: CGDisplayBounds(displayID))
    }
    private var flags:CGEventFlags {
        MacKeyEvents.flags(for: held)
    }
    public func apply(_ input:InputEvent) {
        guard input.isValid,AXIsProcessTrusted() else{return}
        if [.move,.leftDown,.leftUp,.rightClick].contains(input.kind) {pointerX=input.x!;pointerY=input.y!}
        switch input.kind {
        case .move:mouse(mouseDown ? .leftMouseDragged:.mouseMoved,point:pointer,button:.left)
        case .leftDown:selectKeyboardTarget(at:pointer);mouseDown=true;mouse(.leftMouseDown,point:pointer,button:.left,count:input.clickCount ?? 1)
        case .leftUp:mouseDown=false;mouse(.leftMouseUp,point:pointer,button:.left,count:input.clickCount ?? 1)
        case .rightClick:
            selectKeyboardTarget(at:pointer)
            mouse(.rightMouseDown,point:pointer,button:.right);mouse(.rightMouseUp,point:pointer,button:.right)
        case .scroll:
            if let event=CGEvent(scrollWheelEvent2Source:nil,units:.pixel,wheelCount:2,wheel1:Int32(input.y!),wheel2:Int32(input.x!),wheel3:0) {
                event.location=pointer;event.flags=flags
                // Route wheel input to the remote pointer's location.
                mouse(.mouseMoved,point:pointer,button:.left)
                event.post(tap:.cghidEventTap)
            }
        case .keyDown:held.insert(input.keyCode!);key(input.keyCode!,down:true)
        case .keyUp:held.remove(input.keyCode!);key(input.keyCode!,down:false)
        case .text:
            for scalar in input.text!.unicodeScalars {
                let chunk=Array(String(scalar).utf16)
                for down in [true,false] {
                    if let event=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:down) {
                        chunk.withUnsafeBufferPointer {event.keyboardSetUnicodeString(stringLength:chunk.count,unicodeString:$0.baseAddress!)}
                        event.flags=flags;postKeyboard(event)
                    }
                }
            }
        case .releaseAll:releaseAll()
        }
    }
    public func reset() {releaseAll();keyboardTargetPID=nil;pointerX=0.5;pointerY=0.5}
    @MainActor
    func waitForKeyboardDelivery() async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        while keyboardActivationPending {
            try Task.checkCancellation()
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                throw NSError(domain: "DuoInput", code: 1, userInfo: [NSLocalizedDescriptionKey: "Keyboard delivery timed out."])
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        try Task.checkCancellation()
    }
    public func releaseAll() {
        keyboardGeneration += 1;pendingKeyboard.removeAll();keyboardActivationPending=false
        let keys=held;held.removeAll()
        for code in keys {
            guard let event=makeKey(code,down:false) else{continue}
            // Releases must not activate another app or remain in a delay queue.
            if globalModifiers.contains(code) { event.post(tap:.cghidEventTap) }
            else if let pid=keyboardTargetPID {event.postToPid(pid)} else {event.post(tap:.cghidEventTap)}
        }
        globalModifiers.removeAll()
        if mouseDown {mouse(.leftMouseUp,point:pointer,button:.left)}
        mouseDown=false
    }
    private func makeKey(_ code:UInt16,down:Bool)->CGEvent? {
        MacKeyEvents.make(code, down: down, held: held)
    }
    private func key(_ code:UInt16,down:Bool) {if let event=makeKey(code,down:down) {postKeyboard(event)}}
    private func mouse(_ type:CGEventType,point:CGPoint,button:CGMouseButton,count:Int=1) {
        let event=CGEvent(mouseEventSource:nil,mouseType:type,mouseCursorPosition:point,mouseButton:button)
        event?.flags=flags;event?.setIntegerValueField(.mouseEventClickState,value:Int64(count));event?.post(tap:.cghidEventTap)
    }
    private func selectKeyboardTarget(at point:CGPoint) {
        guard routesKeyboardToRemoteWindow else{keyboardTargetPID=nil;return}
        let windows=CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as? [[String:Any]] ?? []
        let target=windows.first(where: {item in
            guard (item[kCGWindowLayer as String] as? Int)==0,
                  let bounds=item[kCGWindowBounds as String] as? [String:Any],
                  let rect=CGRect(dictionaryRepresentation:bounds as CFDictionary) else{return false}
            return rect.contains(point)
        })
        keyboardTargetPID=target?[kCGWindowOwnerPID as String] as? pid_t
    }
    private func postKeyboard(_ event:CGEvent) {
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if MacKeyEvents.modifierCodes.contains(code), nativeTouchActive || globalModifiers.contains(code) {
            if held.contains(code) { globalModifiers.insert(code) } else { globalModifiers.remove(code) }
            event.post(tap:.cghidEventTap)
            return
        }
        guard routesKeyboardToRemoteWindow else{event.post(tap:.cghidEventTap);return}
        // Virtual-display keys need a target process to avoid typing into the host's active app.
        guard let pid=keyboardTargetPID,let app=NSRunningApplication(processIdentifier:pid),!app.isTerminated else{return}
        if app.isActive && !keyboardActivationPending {event.postToPid(pid);return}
        pendingKeyboard.append(event)
        guard !keyboardActivationPending else{return}
        keyboardActivationPending=true
        let generation=keyboardGeneration
        app.activate(options:[])
        DispatchQueue.main.asyncAfter(deadline:.now()+0.12) {[weak self] in
            guard let self,self.keyboardGeneration==generation else{return}
            let events=self.pendingKeyboard;self.pendingKeyboard.removeAll();self.keyboardActivationPending=false
            for event in events {event.postToPid(pid)}
        }
    }
}
