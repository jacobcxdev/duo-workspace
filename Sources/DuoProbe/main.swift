import Foundation
import AppKit
import IOKit
import CoreGraphics
import CoreVideo
import DuoCore
import DuoHost

func displays()->[UInt32]{var n:UInt32=0;CGGetOnlineDisplayList(0,nil,&n);var a=[UInt32](repeating:0,count:Int(n));CGGetOnlineDisplayList(n,&a,&n);return Array(a.prefix(Int(n)))}
func clamshell()->Bool? {let service=IOServiceGetMatchingService(kIOMainPortDefault,IOServiceMatching("IOPMrootDomain"));defer{IOObjectRelease(service)};return IORegistryEntryCreateCFProperty(service,"AppleClamshellState" as CFString,kCFAllocatorDefault,0)?.takeRetainedValue() as? Bool}
func report(_ values:[String:Any]){if let d=try? JSONSerialization.data(withJSONObject:values,options:[.sortedKeys]),let s=String(data:d,encoding:.utf8){print(s);fflush(stdout)}}

let args=CommandLine.arguments
let before=displays()
report(["stage":"preflight","screenCapturePermission":CGPreflightScreenCaptureAccess(),"inputPermission":AXIsProcessTrusted(),"virtualAPI":VirtualDisplayHandle.isAvailable,"displayCount":before.count,"lidClosed":clamshell() as Any? ?? "unknown"])
if args.contains("--request-capture"){report(["stage":"permissionRequest","granted":CGRequestScreenCaptureAccess()])}
var handle:VirtualDisplayHandle?
if args.contains("--virtual") {
    do{handle=try VirtualDisplayHandle();RunLoop.current.run(until:Date().addingTimeInterval(1));let mode=CGDisplayCopyDisplayMode(handle!.displayID)
        report(["stage":"virtualCreated","displayID":handle!.displayID,"listed":displays().contains(handle!.displayID),"width":CGDisplayPixelsWide(handle!.displayID),"height":CGDisplayPixelsHigh(handle!.displayID),"pixelWidth":mode?.pixelWidth ?? 0,"pixelHeight":mode?.pixelHeight ?? 0])}
    catch{report(["stage":"virtualFailed","error":error.localizedDescription])}
}
var duration=6.0
if let i=args.firstIndex(of:"--seconds"),args.count>i+1,let n=Double(args[i+1]){duration=min(120,max(1,n))}
if args.contains("--capture") {
    let capture=CaptureEngine();var frames=0,encoded=0,totalBytes=0
    do{
        let encoder=try H264Encoder(width:1600,height:1000)
        encoder.onOutput={frame in encoded += 1;totalBytes += frame.data.count}
        capture.onFrame={buffer,time in frames += 1;encoder.encode(buffer,time:time)}
        capture.onError={report(["stage":"captureError","error":$0.message,"domain":$0.domain,"code":$0.code])}
        let id=handle?.displayID ?? CGMainDisplayID()
        var finished=false
        Task {
            do{try await capture.start(displayID:id);report(["stage":"captureStarted"])}catch{report(["stage":"captureDenied","error":error.localizedDescription])}
            finished=true
        }
        let start=Date();while !finished && Date().timeIntervalSince(start)<10 {RunLoop.current.run(until:Date().addingTimeInterval(0.1))}
        let end=Date().addingTimeInterval(duration)
        while Date()<end {RunLoop.current.run(until:Date().addingTimeInterval(0.2))}
        Task{await capture.stop()};RunLoop.current.run(until:Date().addingTimeInterval(0.5));encoder.finish()
        report(["stage":"captureResult","frames":frames,"encodedFrames":encoded,"bytes":totalBytes,"lidClosed":clamshell() as Any? ?? "unknown"])
    }catch{report(["stage":"encoderError","error":error.localizedDescription])}
}
handle?.close();handle=nil;RunLoop.current.run(until:Date().addingTimeInterval(3))
report(["stage":"cleanup","displayCount":displays().count,"originalDisplaysRetained":Set(before).isSubset(of:Set(displays()))])
