import SwiftUI
import DuoCore

struct NativeTouchInfo: View {
    var session: SessionNativeTouch?
    var retry: (() -> Void)?

    var body: some View {
        if let session {
            if !session.supported {
                Text("Native touch needs macOS 27.3 and the current Duo Workspace Host. Touch mode is active on this Mac.")
            } else {
                switch session.status.state {
                case .ready:
                    Text("Your Mac receives up to five fingers and handles the gestures. The lower tabletop trackpad keeps its usual controls.")
                case .starting:
                    Text("Starting native touch on your Mac…")
                case .paused:
                    Text("Native touch is paused while the desktop changes. Lift your fingers before continuing.")
                case .unavailable:
                    Text(failureMessage(session.status.failure))
                    if let retry { Button("Retry native touch", action: retry) }
                case .off:
                    Text("Native touch starts when this device connects with control access.")
                }
            }
        } else {
            Text("Send up to five fingers to your Mac. Native touch needs macOS 27.3 and a host configured for virtual touch input.")
        }
    }

    private func failureMessage(_ failure: NativeTouchStatus.Failure?) -> LocalizedStringResource {
        switch failure {
        case .macOSVersion: "Native touch needs macOS 27.3. Touch mode is active."
        case .permission: "Allow input access for Duo Workspace Host on your Mac, then retry. Touch mode is active."
        case .display: "The Mac display changed. Retry native touch after it settles. Touch mode is active."
        default: "Your Mac couldn't start native touch. Check the host's virtual touch setup, then retry. Touch mode is active."
        }
    }
}
