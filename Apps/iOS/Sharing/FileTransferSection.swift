import SwiftUI

struct FileTransferSection: View {
    let files: SessionFiles
    let importFailed: Bool

    var body: some View {
        let download = files.receivedFiles.first { $0.url == files.transfer.receivedURL }
        if files.transfer.offer != nil || files.transfer.state.isBusy || files.transfer.failure != nil || files.message != nil || importFailed {
            Section {
                FileTransferProgress(transfer: files.transfer, hasDownload: download != nil)
                if files.transfer.state == .awaitingAcceptance {
                    Button("Receive file", systemImage: "square.and.arrow.down", action: files.receiveFile)
                        .accessibilityIdentifier("files.receive")
                }
                if files.transfer.state.isBusy {
                    Button("Cancel transfer", role: .cancel, action: files.cancel)
                        .accessibilityIdentifier("files.cancel")
                }
                if files.transfer.state == .completed, let download {
                    ShareLink(item: download.url) { Label("Save or share file", systemImage: "square.and.arrow.up") }
                        .accessibilityLabel("Save or share \(download.name)")
                        .accessibilityIdentifier("files.saveCurrent")
                }
                if let message = files.message { Text(message).foregroundStyle(.secondary) }
                if importFailed { Text("Couldn't open that file. Choose it again in Files.") }
            }
        }
    }
}
