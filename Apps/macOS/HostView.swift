import SwiftUI
import DuoHost

struct HostView: View {
    let host: HostController

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "display.2").font(.largeTitle).foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Mac, on Duo").font(.title2.bold())
                        Text(host.status).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                Button(host.sharing ? "Stop sharing" : "Start sharing") {
                    host.sharing ? host.stop() : host.start()
                }
                .buttonStyle(.borderedProminent).foregroundStyle(Color("OnAccent")).controlSize(.large)
                .disabled(!host.access.isReady)
            }
            Section("Permissions") {
                PermissionRow(title: "Screen recording", detail: "Show this Mac’s display on your device.",
                              allowed: host.captureAllowed, action: host.requestCapture)
                PermissionRow(title: "Accessibility", detail: "Control this Mac with your device’s pointer and keyboard.",
                              allowed: host.inputAllowed, action: host.requestInput)
            }
            PairingApprovalSection(access: host.access)
            PairingSection(host: host)
            DeviceAccessSection(access: host.access)
            Section("Duo Microphone") {
                Text(host.microphone.available ? "Installed. Choose Duo Microphone as the input in your Mac app." : "Install the input device to use your iPhone's microphone on this Mac.")
                Button("Install microphone device", action: host.installMicrophone)
            }
            #if DEBUG
            Section("Input test") {
                LabeledContent("Input packets", value: "\(host.receivedInputCount) · \(host.lastInputKind)")
                Text(host.inputDiagnostics).font(.caption).textSelection(.enabled)
                Button("Open input test window") { InputTestWindow.shared.show(displayID: host.activeDisplayID) }
            }
            #endif
        }
        .formStyle(.grouped)
        .tint(.accentColor)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in host.refreshPermissions() }
    }

}
