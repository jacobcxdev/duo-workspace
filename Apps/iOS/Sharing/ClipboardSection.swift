import SwiftUI

struct ClipboardSection: View {
    let clipboard: SessionClipboard
    let available: Bool

    var body: some View {
        Section {
            LabeledContent("Send text to Mac") {
                PasteButton(payloadType: String.self) { values in
                    if let text = values.first { clipboard.sendText(text) }
                }
                .labelStyle(.titleAndIcon)
                .accessibilityLabel("Paste text to Mac clipboard")
                .accessibilityIdentifier("clipboard.send")
            }
            Button("Get Mac clipboard", systemImage: "doc.on.clipboard", action: clipboard.getText)
                .accessibilityIdentifier("clipboard.get")
            if clipboard.isBusy { ProgressView("Sharing text…") }
            if let message = clipboard.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
        } header: { Text("Clipboard") }
        footer: { Text("Shares text when you choose an action. Pasting into a Mac app is a separate step.") }
        .disabled(!available || clipboard.isBusy)
    }
}
