import SwiftUI
import DuoCore

struct ModifierKeys: View {
    let input: SessionInputController

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RemoteModifier.allCases, id: \.self) { modifier in
                ModifierKey(input: input, modifier: modifier)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
