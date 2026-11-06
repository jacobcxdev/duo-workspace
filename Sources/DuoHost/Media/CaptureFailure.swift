import Foundation
import ScreenCaptureKit

/// Classifies capture errors separately from connection failures.
public struct CaptureFailure: Error, LocalizedError, Sendable {
    public let domain: String
    public let code: Int
    public let message: String

    public init(_ error: Error) {
        if let failure = error as? CaptureFailure {
            self = failure
            return
        }
        let error = error as NSError
        domain = error.domain
        code = error.code
        message = error.localizedDescription
    }

    public var errorDescription: String? { message }

    var canRestartCapture: Bool {
        if domain == NSCocoaErrorDomain {
            return code == NSXPCConnectionInterrupted || code == NSXPCConnectionInvalid
        }
        guard domain == SCStreamErrorDomain else { return false }
        return [SCStreamError.Code.failedApplicationConnectionInvalid.rawValue,
                SCStreamError.Code.failedApplicationConnectionInterrupted.rawValue,
                SCStreamError.Code.internalError.rawValue].contains(code)
    }

    var requiresUserAction: Bool {
        guard domain == SCStreamErrorDomain else { return false }
        if #available(macOS 15, *), code == SCStreamError.Code.systemStoppedStream.rawValue { return true }
        return [SCStreamError.Code.userDeclined.rawValue,
                SCStreamError.Code.userStopped.rawValue,
                SCStreamError.Code.missingEntitlements.rawValue].contains(code)
    }
}
