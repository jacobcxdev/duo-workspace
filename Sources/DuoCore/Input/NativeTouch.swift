import Foundation

public struct NativeTouchContact: Codable, Equatable, Sendable {
    public let id: UInt8
    public let x: Double
    public let y: Double

    public init(id: UInt8, x: Double, y: Double) {
        self.id = id; self.x = x; self.y = y
    }

    public var isValid: Bool {
        (1...127).contains(id) && x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y)
    }
}

/// A full contact snapshot tied to one display context. Resizing invalidates it.
public struct NativeTouchFrame: Codable, Equatable, Sendable {
    public static let maximumContacts = 5
    public let contextID: UUID
    public let contacts: [NativeTouchContact]

    public init(contextID: UUID, contacts: [NativeTouchContact]) {
        self.contextID = contextID; self.contacts = contacts
    }

    public var isValid: Bool {
        contacts.count <= Self.maximumContacts && contacts.allSatisfy(\.isValid)
            && Set(contacts.map(\.id)).count == contacts.count
    }
}

public struct NativeTouchControl: Codable, Sendable {
    public let enabled: Bool
    public init(enabled: Bool) { self.enabled = enabled }
}

public struct NativeTouchStatus: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable { case off, starting, ready, paused, unavailable }
    public enum Failure: String, Codable, Sendable { case macOSVersion, permission, device, display, timedOut }
    public let state: State
    public let contextID: UUID?
    public let failure: Failure?

    public init(_ state: State, contextID: UUID? = nil, failure: Failure? = nil) {
        self.state = state; self.contextID = contextID; self.failure = failure
    }

    public var isValid: Bool {
        (state == .ready) == (contextID != nil) && (state != .ready || failure == nil)
    }
}
