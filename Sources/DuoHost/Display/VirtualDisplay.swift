import Foundation
import CoreGraphics
import VirtualDisplayBridge

public final class VirtualDisplayHandle {
    private var handle:UnsafeMutableRawPointer?
    public private(set) var displayID:CGDirectDisplayID=0
    public static var isAvailable:Bool {DuoVirtualDisplayAvailable()}
    public init(width:Int=1600,height:Int=1000, scale:Int=1) throws {
        var id:UInt32=0
        handle=DuoCreateAdaptiveDisplay(UInt32(clamping:width),UInt32(clamping:height),UInt32(clamping:scale),&id)
        guard handle != nil else {throw NSError(domain:"DuoVirtualDisplay",code:1,userInfo:[NSLocalizedDescriptionKey:"Virtual display unavailable"])}
        displayID=id

    }
    @MainActor
    public func resize(width: Int, height: Int, scale: Int) async throws {
        try Task.checkCancellation()
        guard let handle, DuoApplyDisplaySize(handle, UInt32(clamping: width), UInt32(clamping: height), UInt32(clamping: scale)) else {
            throw NSError(domain: "DuoVirtualDisplay", code: 2, userInfo: [NSLocalizedDescriptionKey: "The Mac couldn't resize this display."])
        }
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        while ProcessInfo.processInfo.systemUptime < deadline {
            try Task.checkCancellation()
            guard self.handle == handle else { throw CancellationError() }
            let selection = DuoSelectDisplaySize(handle, UInt32(clamping: width), UInt32(clamping: height), UInt32(clamping: scale))
            if selection == DuoDisplaySelectionReady { return }
            if selection == DuoDisplaySelectionFailed { break }
            try await Task.sleep(for: .milliseconds(80))
        }
        throw NSError(domain: "DuoVirtualDisplay", code: 3, userInfo: [NSLocalizedDescriptionKey: "The Mac didn't accept the requested display size."])
    }
    public func close(){if let handle {DuoReleaseVirtualDisplay(handle);self.handle=nil;displayID=0}}
    deinit{close()}
}
