import SwiftUI

@available(iOS 27.1, *)
struct FoldWorkspace: View {
    let model: SessionModel
    @Binding var keyboard: Bool
    @Binding var keyboardFocused: Bool
    let keyboardPresentation: KeyboardPresentation
    let chrome: WorkspaceChrome
    let showSession: () -> Void
    let hideControls: () -> Void
    let keyboardControlsOwner: KeyboardControlsOwner
    let prefersNativeKeyboardControls: Bool
    let keyboardControlsRequested: (KeyboardControlsOwner) -> Void
    @ScaledMetric(relativeTo: .body) private var minimumTrackpadPaneHeight = 220.0

    var body: some View {
        GeometryReader { geometry in
            let controlMinimum = max(220, minimumTrackpadPaneHeight)
            let division = geometry.reservedRegions(kind: .division).first(where: \.isActive)
            let lowerHeight = geometry.size.height - (division.map { $0.frame.maxY + $0.margins.bottom } ?? geometry.size.height)
            let requestedControls = KeyboardControlsOwner.preferred(division: division?.frame,
                lowerPaneCanFitControls: lowerHeight >= controlMinimum,
                inputEnabled: model.canControl && model.hasVideo,
                prefersNativeAccessibility: prefersNativeKeyboardControls)
            let tabletop = WorkspaceLayoutPolicy.usesTabletopPanes(division: division?.frame, keyboardMode: keyboard,
                                                       softwareKeyboardVisible: keyboardPresentation.hasSoftwareKeys,
                                                       inputEnabled: model.canControl && model.hasVideo,
                                                       controlsVisible: chrome.reservesControlPane,
                                                       lowerPaneCanFitControls: lowerHeight >= controlMinimum)
            let context = WorkspaceViewportContext(rootSize: geometry.size, layout: tabletop ? .tabletop : .canvas,
                                                   keyboardMode: keyboard, keyboardPresentation: keyboardPresentation)
            ZStack {
                if tabletop {
                    ArrangementView {
                        KeyboardAvoidingRegion {
                            WorkspaceView(model: model, viewportContext: context,
                                          revealControls: chrome.isVisible ? nil : { chrome.show() })
                        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } secondary: {
                        TabletopWorkspaceControls(model: model, keyboard: $keyboard, keyboardFocused: $keyboardFocused,
                                                  presentation: keyboardPresentation, owner: keyboardControlsOwner,
                                                  minimumHeight: controlMinimum,
                                                  showSession: showSession, hideControls: hideControls)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.regularMaterial)
                        .modifier(WorkspaceChromeEffect(visible: chrome.isVisible))
                    }
                    .arrangementViewStyle(.split)
                } else {
                    KeyboardAvoidingRegion {
                        FlatWorkspace(model: model, viewportContext: context, keyboard: $keyboard, keyboardFocused: $keyboardFocused,
                                      nativeKeyboardVisible: keyboardControlsOwner.hasVisibleAccessory(for: keyboardPresentation),
                                      chrome: chrome, showSession: showSession, hideControls: hideControls)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onChange(of: context, initial: true) { model.display.selectViewport(context) }
            .onChange(of: requestedControls, initial: true) { _, owner in keyboardControlsRequested(owner) }
        }
    }
}
