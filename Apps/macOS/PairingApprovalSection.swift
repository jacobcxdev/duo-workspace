import SwiftUI
import DuoHost

struct PairingApprovalSection: View {
    let access: DeviceAccessController

    var body: some View {
        if !access.pending.isEmpty {
            Section("Device approval") {
                ForEach(access.pending) { request in
                    VStack(alignment: .leading, spacing: 12) {
                        Label(request.name, systemImage: "iphone.and.arrow.forward")
                            .font(.headline)
                        Text("Approve only if this code matches your device.")
                        Text(request.verificationCode).font(.system(.largeTitle, design: .monospaced).bold()).textSelection(.enabled)
                            .accessibilityLabel("Verification code")
                            .accessibilityValue(request.verificationCode.map(String.init).joined(separator: ", "))
                        Text("This device can view and control your Mac while sharing is on.").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Decline", role: .cancel) { access.deny(request.id) }
                            Button("Approve device") { access.approve(request.id) }.buttonStyle(.borderedProminent).foregroundStyle(Color("OnAccent"))
                        }
                    }
                }
            }
        }
    }
}
