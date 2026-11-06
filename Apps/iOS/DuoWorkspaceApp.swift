import SwiftUI

@main
struct DuoWorkspaceApp: App {
    @State private var model = SessionModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MacsView(model: model)
                .tint(.accentColor)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.setSceneActive(true) }
                    else { model.releaseInput() }
                    if phase == .background { model.setSceneActive(false) }
                }
        }
    }
}
