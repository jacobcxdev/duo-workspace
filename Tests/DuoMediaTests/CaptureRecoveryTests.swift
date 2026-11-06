import Foundation
import ScreenCaptureKit
import Testing
@testable import DuoHost

struct CaptureRecoveryTests {
    @Test func wrappingAnExistingCaptureFailurePreservesItsCategory() {
        for code in [SCStreamError.Code.failedApplicationConnectionInterrupted, .userStopped] {
            let original = CaptureFailure(NSError(domain: SCStreamErrorDomain, code: code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Test capture failure"]))
            let wrapped = CaptureFailure(original)
            #expect(wrapped.domain == original.domain && wrapped.code == original.code)
            #expect(wrapped.message == original.message)
            #expect(wrapped.canRestartCapture == original.canRestartCapture)
            #expect(wrapped.requiresUserAction == original.requiresUserAction)
        }
    }

    @Test func serviceFailuresCanRecoverButConsentAndConfigurationErrorsCannot() {
        for code in [SCStreamError.Code.failedApplicationConnectionInvalid,
                     .failedApplicationConnectionInterrupted, .internalError] {
            let failure = CaptureFailure(NSError(domain: SCStreamErrorDomain, code: code.rawValue))
            #expect(failure.canRestartCapture && !failure.requiresUserAction)
            #expect(failure.domain == SCStreamErrorDomain && failure.code == code.rawValue)
        }
        for code in [SCStreamError.Code.userDeclined, .userStopped, .missingEntitlements] {
            let failure = CaptureFailure(NSError(domain: SCStreamErrorDomain, code: code.rawValue))
            #expect(!failure.canRestartCapture && failure.requiresUserAction)
        }
        for code in [SCStreamError.Code.invalidParameter, .noCaptureSource, .failedNoMatchingApplicationContext] {
            #expect(!CaptureFailure(NSError(domain: SCStreamErrorDomain, code: code.rawValue)).canRestartCapture)
        }
        #expect(!CaptureFailure(NSError(domain: "Other", code: -3805)).canRestartCapture)
        if #available(macOS 15, *) {
            let stopped = CaptureFailure(NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.systemStoppedStream.rawValue))
            #expect(!stopped.canRestartCapture && stopped.requiresUserAction)
        }
    }

    @Test func repeatedServiceFailuresHaveASlidingRestartLimit() {
        var budget = CaptureRecoveryBudget()
        let outcomes = [Double.nan, -1, 100, 110, 159.99, 99, 160, 160.01, 170].map {
            budget.beginAttempt(now: $0)
        }
        #expect(outcomes == [false, false, true, true, false, false, true, false, true])
    }
}
