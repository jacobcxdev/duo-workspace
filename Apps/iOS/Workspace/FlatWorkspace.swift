import SwiftUI

struct FlatWorkspace: View {
    let model: SessionModel
    let viewportContext: WorkspaceViewportContext
    @Binding var keyboard: Bool
    @Binding var keyboardFocused: Bool
    let nativeKeyboardVisible: Bool
    let chrome: WorkspaceChrome
    let showSession: () -> Void
    let hideControls: () -> Void
    @Environment(\.layoutDirection) private var direction
    @State private var dockSize = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            let dock = dockRegion(in: geometry)
            let area = CGRect(x: 10, y: 10, width: max(0, geometry.size.width - 20), height: max(0, geometry.size.height - 20))
            let origin = preferredOrigin(in: geometry.size, alignment: dock.alignment)
            let placement = SessionControlPlacement.frame(in: area, size: dockSize, avoiding: WorkspaceExclusions.rects(in: geometry, direction: direction),
                                                          trailing: direction != .rightToLeft, preferredOrigin: origin)
            ZStack {
                WorkspaceView(model: model, viewportContext: viewportContext,
                              revealControls: chrome.isVisible ? nil : { chrome.show() })
                if !nativeKeyboardVisible {
                    WorkspaceDockContent(model: model, keyboard: $keyboard, keyboardFocused: $keyboardFocused,
                                         chrome: chrome, showSession: showSession, hideControls: hideControls, width: dock.width)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                            var transaction = Transaction(animation: nil)
                            transaction.disablesAnimations = true
                            withTransaction(transaction) { dockSize = size }
                        }
                        .opacity(dockSize == .zero || placement == nil ? 0 : 1)
                        .allowsHitTesting(chrome.isVisible && dockSize != .zero && placement != nil)
                        .accessibilityHidden(!chrome.isVisible || dockSize == .zero || placement == nil)
                        .position(x: placement?.midX ?? geometry.size.width / 2,
                                  y: placement?.midY ?? geometry.size.height / 2)
                }
            }
        }
    }

    private func preferredOrigin(in size: CGSize, alignment: Alignment) -> CGPoint {
        let x: CGFloat
        if alignment == .bottom { x = (size.width - dockSize.width) / 2 }
        else {
            let right = (alignment == .bottomTrailing) == (direction != .rightToLeft)
            x = right ? size.width - dockSize.width - 10 : 10
        }
        return CGPoint(x: x, y: size.height - dockSize.height - 10)
    }

    private func dockRegion(in geometry: GeometryProxy) -> (width: CGFloat, alignment: Alignment) {
        if #available(iOS 27.1, *),
           let division = geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
            .first(where: { $0.isActive && $0.frame.height > $0.frame.width }) {
            let leftMargin = direction == .rightToLeft ? division.margins.trailing : division.margins.leading
            let rightMargin = direction == .rightToLeft ? division.margins.leading : division.margins.trailing
            let left = max(0, division.frame.minX - leftMargin)
            let right = max(0, geometry.size.width - division.frame.maxX - rightMargin)
            let trailing = direction == .rightToLeft ? left : right
            let leading = direction == .rightToLeft ? right : left
            return (min(540, max(0, max(left, right) - 20)), trailing >= leading ? .bottomTrailing : .bottomLeading)
        }
        return (min(540, max(0, geometry.size.width - 20)), .bottom)
    }
}
