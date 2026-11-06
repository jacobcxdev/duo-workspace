import SwiftUI

struct WorkspaceChromeEffect: ViewModifier {
    let visible: Bool
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .transaction { $0.animation = nil }
            .opacity(visible && appeared ? 1 : 0)
            .offset(y: reduceMotion || (visible && appeared) ? 0 : 10)
            .animation(WorkspaceChrome.animation(reduceMotion: reduceMotion), value: visible && appeared)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
            .onAppear { appeared = true }
            .onDisappear { appeared = false }
    }
}
