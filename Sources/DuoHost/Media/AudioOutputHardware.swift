import Foundation

@MainActor
protocol AudioOutputHardware: AnyObject {
    var changed: (() -> Void)? { get set }
    var defaultOutput: UInt32? { get }
    func muteState(of device: UInt32) -> Bool?
    func setMute(_ muted: Bool, on device: UInt32) throws
}
