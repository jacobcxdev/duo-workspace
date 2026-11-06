import Foundation
import IOKit.pwr_mgt

/// Prevents idle sleep during a stream. Explicit sleep and lid policy still apply.
final class SessionWakeAssertion {
    private var identifier: IOPMAssertionID = 0
    func acquire() {
        guard identifier == 0 else { return }
        var value: IOPMAssertionID = 0
        if IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), "Duo Workspace active session" as CFString, &value) == kIOReturnSuccess {
            identifier = value
        }
    }
    func release() {
        guard identifier != 0 else { return }
        IOPMAssertionRelease(identifier)
        identifier = 0
    }
    deinit { release() }
}
