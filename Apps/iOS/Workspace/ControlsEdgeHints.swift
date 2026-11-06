import SwiftUI

struct ControlsEdgeHints: View {
    let visible: Bool
    @Environment(\.layoutDirection) private var direction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size)
            let blocked = WorkspaceExclusions.rects(in: geometry, direction: direction)
            ForEach([false, true], id: \.self) { right in
                if let frame = ControlsRevealGesture.hintFrame(in: bounds, trailing: right, avoiding: blocked) {
                    Capsule()
                        .fill(.white.opacity(contrast == .increased ? 0.95 : 0.6))
                        .overlay { Capsule().strokeBorder(.black.opacity(0.5), lineWidth: 0.5) }
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .opacity(visible ? 1 : 0)
        .animation(WorkspaceChrome.animation(reduceMotion: reduceMotion), value: visible)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
