public enum FileTransferState: Equatable, Sendable {
    case idle, preparing, offering, awaitingAcceptance, sending, receiving, finishing, completed, failed
    public var isBusy: Bool { self != .idle && self != .completed && self != .failed }
}
