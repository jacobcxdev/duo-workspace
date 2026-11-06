import SwiftUI
import DuoCore

struct SessionDetailsView: View {
    let model: SessionModel
    let close: () -> Void
    let hideControls: () -> Void
    let chooseFileOnMac: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        SettingsForm(settings: model.settings, inSession: true, workspaceMode: model.display.mode,
                                     desktop: model.display.desktop, canUpdateDisplayMatch: model.display.currentDisplayInfo != nil,
                                     updateDisplayMatch: model.display.updateDisplayMatch,
                                     nativeTouch: model.nativeTouch, retryNativeTouch: model.retryNativeTouch)
                    } label: { Label("Settings", systemImage: "slider.horizontal.3") }
                    PointerModePicker(settings: model.settings)
                    if model.settings.pointerMode == .nativeTouch {
                        NativeTouchInfo(session: model.nativeTouch, retry: model.retryNativeTouch)
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    MacKeysMenu(input: model.input)
                        .disabled(!model.canSendInput)
                    Button("Release all keys & buttons", systemImage: "hand.raised", action: model.releaseInput)
                    Button("Hide controls", systemImage: "eye.slash") { hideControls(); close() }
                        .accessibilityHint("Swipe inward at either side mark to show controls.")
                        .accessibilityIdentifier("session.hideControls")
                    Button("Reconnect", systemImage: "arrow.clockwise") { close(); model.reconnect() }
                    Button("Disconnect", systemImage: "xmark.circle", role: .destructive) { model.disconnect() }
                        .accessibilityIdentifier("session.disconnect")
                }
                ClipboardSection(clipboard: model.clipboard, available: model.supportsClipboard && model.canSendInput)
                AudioSection(audio: model.audio, available: model.supportsAudio && model.hasVideo)
                MicrophoneSection(microphone: model.microphone, canControl: model.canSendInput)
                if model.supportsFileTransfer {
                    Section {
                        NavigationLink {
                            FilesView(files: model.files, showMac: close, chooseFileOnMac: chooseFileOnMac)
                        } label: {
                            Label(model.files.transfer.state == .awaitingAcceptance ? "Receive file" : "Files", systemImage: "folder")
                        }
                        .accessibilityIdentifier("session.files")
                        .disabled(!model.canSendInput)
                    }
                }
                Section("Workspace") {
                    LabeledContent("Mac", value: model.active?.name ?? "Mac")
                    LabeledContent("Mode", value: model.display.mode == .extend ? "Use as Display" : "Control Mac")
                    LabeledContent("Status", value: model.message)
                    LabeledContent("Input", value: model.canControl ? "Enabled" : "View only")
                }
                Section("Connection") {
                    LabeledContent("Address", value: model.active?.address ?? "")
                    if model.streamWidth > 0 {
                        LabeledContent("Picture", value: "\(model.streamWidth) × \(model.streamHeight)")
                        LabeledContent("Picture quality") { StreamQualityLabel(quality: model.display.quality) }
                        LabeledContent("Target bitrate", value: "\(model.display.quality.bitRate / 1_000_000) Mbps")
                        if model.display.qualityLimitedByHost {
                            Text("This host uses Sharp. Update Duo Workspace Host for Maximum detail.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if let desktop = model.display.desktop {
                        LabeledContent("Mac workspace", value: "\(desktop.width) × \(desktop.height)")
                        LabeledContent("Mac image", value: "\(desktop.width * desktop.scale) × \(desktop.height * desktop.scale)")
                        Text("Mac workspace is the size used to lay out windows and text.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if let info = model.display.currentDisplayInfo {
                        let pixels = info.pixels(viewportWidth: info.pointWidth, viewportHeight: info.pointHeight) ?? info.pixels
                        LabeledContent("Display pixels", value: "\(pixels.width) × \(pixels.height)")
                        #if targetEnvironment(simulator)
                        Text("These are the simulator's display pixels. Physical devices report their own display size.")
                            .font(.footnote).foregroundStyle(.secondary)
                        #endif
                    }
                    if let milliseconds = model.roundTripMilliseconds {
                        LabeledContent("Round trip") { Text("\(milliseconds, format: .number.precision(.fractionLength(0))) ms") }
                    }
                    SessionFrameCount(model: model)
                    Text("Round trip measures a message’s journey to the Mac and back.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

            }
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(VisibleSessionNavigationBar())
            .toolbar { SessionDoneToolbar(close: close) }
        }
    }
}
