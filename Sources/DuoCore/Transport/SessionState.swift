public enum SessionState: Equatable, Sendable {
    case disconnected, connecting, authenticating, waitingForFrame, connected, reconnecting
    case failed(String)
}
