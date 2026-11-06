import SwiftUI

struct SessionPanelView: View {
    let sheet: SessionSheet
    let model: SessionModel
    let close: () -> Void
    let hideControls: () -> Void
    let chooseFileOnMac: () -> Void

    var body: some View {
        switch sheet.destination {
        case .session:
            SessionDetailsView(model: model, close: close, hideControls: hideControls, chooseFileOnMac: chooseFileOnMac)
        case .files:
            NavigationStack {
                FilesView(files: model.files, showMac: close, chooseFileOnMac: chooseFileOnMac)
                    .toolbar { SessionDoneToolbar(close: close) }
            }
        }
    }
}
