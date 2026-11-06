import Observation

@MainActor @Observable
final class SessionPresentation {
    enum DismissalEffect: Equatable { case none, chooseFileOnMac }
    var sheet: SessionSheet? {
        didSet {
            if oldValue != nil && sheet == nil { isDismissing = true }
        }
    }
    private(set) var isDismissing = false
    @ObservationIgnored private var queuedDestination: SessionSheet.Destination?
    @ObservationIgnored private var startsMacPickerAfterDismissal = false
    @ObservationIgnored private var hasFileOffer = false

    func showSession() { present(.session) }
    func showFiles() { present(.files) }

    private func present(_ destination: SessionSheet.Destination) {
        guard sheet == nil else { return }
        if isDismissing { queuedDestination = destination }
        else { sheet = SessionSheet(destination: destination) }
    }

    func dismiss() { sheet = nil }

    func chooseFileOnMac() {
        guard sheet != nil else { return }
        startsMacPickerAfterDismissal = true
        queuedDestination = nil
        dismiss()
    }

    func fileOfferChanged(available: Bool) {
        hasFileOffer = available
        if available, sheet == nil { present(.files) }
        else if !available, queuedDestination == .files { queuedDestination = nil }
    }

    func didDismiss() -> DismissalEffect {
        sheet = nil
        isDismissing = false
        if startsMacPickerAfterDismissal {
            startsMacPickerAfterDismissal = false
            queuedDestination = nil
            return .chooseFileOnMac
        }
        let next = queuedDestination
        queuedDestination = nil
        if let next, next != .files || hasFileOffer { present(next) }
        return .none
    }

    func reset() {
        sheet = nil; isDismissing = false
        queuedDestination = nil; startsMacPickerAfterDismissal = false; hasFileOffer = false
    }
}
