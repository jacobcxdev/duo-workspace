import SwiftUI
import DuoCore

struct WorkspaceView: View {
    let model: SessionModel
    let viewportContext: WorkspaceViewportContext
    var revealControls: (() -> Void)?

    var body: some View {
        ZStack {
            ZStack {
                Color.black
                SampleVideoView(renderer: model.renderer, isActive: model.display.viewportContext == viewportContext,
                                isCurrentContext: { model.display.viewportContext == viewportContext }) {
                    model.display.reportViewport($0, display: $1, context: viewportContext)
                }
                    .accessibilityHidden(true)
                PointerSurface(input: model.input, enabled: model.canSendInput,
                               mode: model.workspacePointerMode, frameAspect: model.frameAspect,
                               nativeTouch: model.nativeTouch,
                               nativeTouchCancellationID: model.nativeTouch.cancellationID,
                               doubleTapAction: model.settings.touchDoubleTapAction, revealControls: revealControls,
                               accessibleName: "Mac desktop pointer")
            }
            .ignoresSafeArea(.container)
            if model.state != .connected { ConnectionOverlay(model: model) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mac workspace")
    }
}
