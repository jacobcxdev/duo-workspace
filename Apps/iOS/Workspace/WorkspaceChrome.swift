import SwiftUI
import Observation

@MainActor @Observable
final class WorkspaceChrome {
    private(set) var isVisible = true
    private(set) var reservesControlPane = true
    @ObservationIgnored private var revision: UInt64 = 0

    static func animation(reduceMotion: Bool) -> Animation {
        .easeOut(duration: reduceMotion ? 0.12 : 0.2)
    }

    func show() {
        revision &+= 1
        reservesControlPane = true
        isVisible = true
    }

    func hide(reduceMotion: Bool) {
        guard isVisible else { return }
        let request = revision &+ 1
        withAnimation(Self.animation(reduceMotion: reduceMotion), completionCriteria: .removed) {
            _ = beginHiding()
        } completion: { [weak self] in self?.finishHiding(request: request) }
    }

    func beginHiding() -> UInt64 {
        revision &+= 1
        isVisible = false
        return revision
    }

    func finishHiding(request: UInt64) {
        guard request == revision, !isVisible else { return }
        reservesControlPane = false
    }
}
