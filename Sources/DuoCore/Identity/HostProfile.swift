import Foundation

public struct HostProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var address: String
    public var port: UInt16
    public var mode: WorkspaceMode
    public init(id: UUID = UUID(), name: String, address: String, port: UInt16 = 47991,
                mode: WorkspaceMode = .control) {
        self.id=id; self.name=name; self.address=address; self.port=port
        self.mode=mode
    }
}
