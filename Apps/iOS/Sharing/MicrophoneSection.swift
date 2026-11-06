import SwiftUI

struct MicrophoneSection: View {
    @Bindable var microphone: SessionMicrophone
    let canControl: Bool

    var body: some View {
        Section("Microphone") {
            Toggle("Send iPhone microphone", isOn: $microphone.enabled)
                .disabled(!canControl || !microphone.supported || !microphone.available)
                .accessibilityIdentifier("microphone.enabled")
            if microphone.sending {
                LabeledContent("Mac input", value: "Duo Microphone")
                ProgressView(value: microphone.peak)
                    .accessibilityLabel("Microphone level")
            }
            if let message = microphone.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            else if !microphone.supported { Text("Update Duo Workspace Host to use the microphone.").font(.footnote).foregroundStyle(.secondary) }
            else if !microphone.available { Text("Install Duo Microphone from the Mac host.").font(.footnote).foregroundStyle(.secondary) }
            else { Text("Choose Duo Microphone as the input in your Mac app.").font(.footnote).foregroundStyle(.secondary) }
        }
    }
}
