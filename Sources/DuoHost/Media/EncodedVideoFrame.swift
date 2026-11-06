import Foundation
import DuoCore

public struct EncodedVideoFrame: Sendable {
    public let configuration: VideoConfiguration?
    public let data: Data
    public let time: TimeInterval
}
