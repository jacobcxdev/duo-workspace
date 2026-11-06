import SwiftUI

struct AudioSection: View {
    @Bindable var audio: SessionAudio
    let available: Bool

    var body: some View {
        Section("Sound") {
            Toggle("Play Mac audio", isOn: $audio.enabled)
                .accessibilityIdentifier("audio.enabled")
                .disabled(!available)
            if audio.enabled {
                LabeledContent("Volume") {
                    Slider(value: $audio.volume, in: 0...1)
                        .accessibilityLabel("Mac audio volume")
                        .accessibilityIdentifier("audio.volume")
                }
                if audio.supportsMacMute {
                    Toggle("Mute Mac while listening here", isOn: $audio.muteMac)
                        .disabled(!available || !audio.canMuteMac)
                        .accessibilityIdentifier("audio.muteMac")
                    if audio.canMuteMac {
                        Text("Restores changes made by Duo when audio stops or you disconnect.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("Use the Mac's sound controls to mute this output.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            if let message = audio.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
        }
    }
}
