import SwiftUI

struct ModifierStrip: View {
    let input: SessionInputController

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ModifierKeys(input: input)
            ScrollView(.horizontal) { ModifierKeys(input: input) }
                .scrollIndicators(.hidden)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
