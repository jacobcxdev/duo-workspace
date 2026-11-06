import SwiftUI
import DuoHost
import DuoCore

struct DeviceAccessSection: View {
    let access: DeviceAccessController
    @State private var revoking: PairedDevice?
    @State private var confirmsRevoke = false

    var body: some View {
        Section("Paired devices") {
            if access.devices.isEmpty { Text("No paired devices yet.").foregroundStyle(.secondary) }
            ForEach(access.devices) { device in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(device.name, systemImage: device.isApproved ? "iphone" : "iphone.slash")
                        Text(device.isApproved ? "Approved" : "Access revoked").font(.caption).foregroundStyle(.secondary)
                        Text(String(device.id.prefix(16))).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if device.isApproved {
                        Button("Revoke access", role: .destructive) { revoking = device; confirmsRevoke = true }
                    }
                }
            }
        }
        .confirmationDialog("Revoke this device’s access?", isPresented: $confirmsRevoke, titleVisibility: .visible) {
            Button("Revoke access", role: .destructive) { if let revoking { access.revoke(revoking.id) } }
        } message: { Text("Ends this device’s session. It needs a new invitation and your approval to reconnect.") }
    }
}
