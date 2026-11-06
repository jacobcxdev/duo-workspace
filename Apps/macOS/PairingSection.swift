import SwiftUI
import DuoHost

struct PairingSection: View {
    let host: HostController
    @State private var copied = false
    @State private var address = ""

    var body: some View {
        Section("Pair a device") {
            Text("Create an invitation, then approve the device here to let it view and control your Mac.")
            if !host.access.isReady {
                Text(host.access.message).foregroundStyle(.secondary)
                Button("Retry Keychain access") { host.access.load() }.disabled(host.access.loading)
            } else if let invitation = host.access.invitation {
                LabeledContent("Invitation expires") { Text(invitation.expiresAt, style: .time) }
                Button(copied ? "Invitation copied" : "Copy invitation", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    guard let link = try? invitation.link() else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(link, forType: .string)
                    copied = true
                }
                Button("Cancel invitation", role: .cancel) { host.access.cancelInvitation(); copied = false }
            } else {
                TextField("Connection address (optional)", text: $address)
                    .help("Leave blank to use this Mac's hostname. You can enter a VPN address.")
                Button("Create invitation", systemImage: "plus.circle") {
                    copied = false
                    let entered = address.trimmingCharacters(in: .whitespacesAndNewlines)
                    host.access.makeInvitation(name: Host.current().localizedName ?? "My Mac",
                                               address: entered.isEmpty ? ProcessInfo.processInfo.hostName : entered)
                }.disabled(!host.sharing)
                if !host.sharing { Text("Start sharing to pair a device.").font(.caption).foregroundStyle(.secondary) }
            }
            if host.access.isReady && !host.access.message.isEmpty { Text(host.access.message).font(.caption).foregroundStyle(.secondary) }
            if host.access.storageWarning != nil {
                if host.access.storageWarning != host.access.message {
                    Text(host.access.storageWarning ?? "").font(.caption).foregroundStyle(.secondary)
                }
                Button("Retry saving") { host.access.retryStorage() }
            }
        }
    }
}
