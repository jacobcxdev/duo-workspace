import SwiftUI

struct SessionStatusBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27, *) { content.toolbarVisibility(.hidden, for: .statusBar) }
        else { content.statusBarHidden(true) }
    }
}
