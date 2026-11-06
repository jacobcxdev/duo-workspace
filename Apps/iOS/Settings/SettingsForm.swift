import SwiftUI
import DuoCore

struct SettingsForm: View {
    @Bindable var settings: AppSettings
    var inSession = false
    var workspaceMode: WorkspaceMode?
    var desktop: DesktopSize?
    var canUpdateDisplayMatch = false
    var updateDisplayMatch: (() -> Void)?
    var nativeTouch: SessionNativeTouch?
    var retryNativeTouch: (() -> Void)?

    var body: some View {
            Form {
                Section {
                    DesktopShapePicker(selection: $settings.desktopShape)
                        .disabled(inSession && workspaceMode == .control)
                    DesktopSizingPicker(selection: $settings.desktopSizing)
                        .disabled(inSession && workspaceMode == .control)
                    if inSession, workspaceMode == .extend, settings.desktopSizing == .matchDisplay,
                       settings.desktopShape != .automatic, let updateDisplayMatch {
                        Button("Update display match", systemImage: "arrow.triangle.2.circlepath", action: updateDisplayMatch)
                            .disabled(!canUpdateDisplayMatch)
                    }
                    if let desktop {
                        LabeledContent("Current Mac size", value: "\(desktop.width) × \(desktop.height)")
                    }
                } header: { Text("Workspace") }
                footer: {
                    if inSession && workspaceMode == .control {
                        Text("Workspace settings apply to Use as Display. Control Mac keeps your Mac's existing desktop size.")
                    } else {
                        Text("Automatic follows the workspace. Fixed shapes keep the Mac desktop size. Changes apply in Use as Display.")
                        Text("More space and Match display make Mac text smaller. Match display uses this screen's native pixels; update a fixed match when you want to use another display's size.")
                    }
                }
                Section {
                    AdaptiveFormPicker("Picture quality", selection: $settings.quality) {
                        Text("Efficient").fixedSize(horizontal: false, vertical: true).tag(StreamQuality.efficient)
                        Text("Balanced").fixedSize(horizontal: false, vertical: true).tag(StreamQuality.balanced)
                        Text("Sharp").fixedSize(horizontal: false, vertical: true).tag(StreamQuality.sharp)
                        Text("Maximum detail").fixedSize(horizontal: false, vertical: true).tag(StreamQuality.maximum)
                    }
                } header: { Text("Display") }
                footer: {
                    Text(inSession ? "Reconnect to apply picture quality. Maximum detail uses more bandwidth." : "Balanced is the default. Maximum detail sends more source pixels and uses more bandwidth.")
                }
                InputSettingsSection(settings: settings, nativeTouch: nativeTouch, retryNativeTouch: retryNativeTouch)
                Section {
                    Toggle("Reconnect automatically", isOn: $settings.automaticReconnect)
                    Toggle("Keep screen awake", isOn: $settings.keepAwake)
                } header: { Text("Connection") }
                footer: { Text("Reconnect tries up to three times. Keep awake prevents screen sleep while the workspace is open.") }
                Section {
                    NavigationLink("Keyboard & gestures") { InputGuideView(settings: settings) }
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")
                    Text("Your Mac must approve this device before it can connect. Revoke access in Duo Workspace Host on the Mac.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("About") }
            }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(VisibleSessionNavigationBar())
    }
}
