import SwiftUI

struct TrackpadView: View {
    let input: SessionInputController
    let showHints: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(.quaternary)
            VStack(spacing: 6) {
                Image(systemName: input.isScrolling ? "arrow.up.and.down.and.arrow.left.and.right" : "cursorarrow")
                    .font(.title2)
                Text(input.isDragging ? "Move to drag" : input.isScrolling ? "Slide to scroll" : "Trackpad")
                    .font(.callout.weight(.medium))
                if showHints {
                    Text("Tap to click · hold to drag").font(.caption).foregroundStyle(.secondary)
                }
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            PointerSurface(input: input, enabled: true)
        }
    }
}
