#if DEBUG
import Foundation
import ScreenCaptureKit
import Darwin

/// Opt-in, process-local fault injection. This never stops replayd or changes
/// screen-recording permission. SIGUSR1 interrupts capture; SIGUSR2 models stop;
/// SIGINFO arms an interruption at the next capture start or display-mode change.
@MainActor
final class DebugCaptureFaults {
    private var sources: [DispatchSourceSignal] = []
    static var interruption: CaptureFailure {
        CaptureFailure(NSError(domain: SCStreamErrorDomain,
            code: SCStreamError.Code.failedApplicationConnectionInterrupted.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Capture test interruption"]))
    }

    init(armResize: @escaping @MainActor () -> Void,
         handler: @escaping @MainActor (CaptureFailure) -> Void) {
        for (number, code) in [(SIGUSR1, SCStreamError.Code.failedApplicationConnectionInterrupted),
                               (SIGUSR2, SCStreamError.Code.userStopped)] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler {
                Task { @MainActor in
                    handler(CaptureFailure(NSError(domain: SCStreamErrorDomain, code: code.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: "Capture test interruption"])))
                }
            }
            source.resume()
            sources.append(source)
        }
        signal(SIGINFO, SIG_IGN)
        let resize = DispatchSource.makeSignalSource(signal: SIGINFO, queue: .main)
        resize.setEventHandler { Task { @MainActor in armResize() } }
        resize.resume()
        sources.append(resize)
    }

    deinit { sources.forEach { $0.cancel() } }
}
#endif
