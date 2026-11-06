import SwiftUI
import DuoCore

struct FileTransferProgress: View {
    let transfer: FileTransferEngine
    let hasDownload: Bool

    var body: some View {
        if let offer = transfer.offer {
            LabeledContent("File", value: offer.name)
            LabeledContent("Size") { Text(Int64(offer.size), format: .byteCount(style: .file)) }
            if transfer.state.isBusy, transfer.state != .awaitingAcceptance {
                ProgressView(value: Double(transfer.transferred), total: Double(max(1, offer.size)))
                Text("\(transfer.transferred) of \(offer.size) bytes")
                    .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
            }
            switch transfer.state {
            case .offering: Text("Waiting for the other device…")
            case .preparing: Text("Preparing file…")
            case .sending: Text("Sending to Mac…")
            case .receiving: Text("Receiving from Mac…")
            case .finishing: Text("Checking file…")
            case .completed:
                if transfer.receivedURL == nil { Text("Saved in Downloads/Duo Workspace on your Mac.") }
                else if hasDownload { Text("Received. Save or share it below.") }
                else { Text("Temporary copy removed.") }
            default: EmptyView()
            }
        }
        if let failure = transfer.failure { FileTransferFailureText(failure: failure) }
    }
}
