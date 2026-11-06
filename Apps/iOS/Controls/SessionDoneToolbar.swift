import SwiftUI

struct SessionDoneToolbar: ToolbarContent {
    let close: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 27, *) {
            ToolbarItem(placement: .topBarPinnedTrailing) {
                Button("Done", action: close).accessibilityIdentifier("session.done")
            }
        } else {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: close).accessibilityIdentifier("session.done")
            }
        }
    }
}
