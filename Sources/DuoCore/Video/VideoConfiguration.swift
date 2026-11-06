import Foundation

public struct VideoConfiguration: Codable, Sendable {
    public var width: Int
    public var height: Int
    public var sps: Data
    public var pps: Data
    public init(width: Int, height: Int, sps: Data, pps: Data) { self.width=width; self.height=height; self.sps=sps; self.pps=pps }
}
