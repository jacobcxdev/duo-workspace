import SwiftUI

struct MacFileSelectionNotice: View {
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Select a file in the Mac dialog, then choose Send.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Cancel", role: .cancel, action: cancel)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 8)
        .accessibilityIdentifier("files.macSelectionNotice")
    }
}
