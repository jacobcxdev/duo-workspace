import SwiftUI
import DuoCore

struct SettingsView: View {
    @Bindable var settings: AppSettings
    var inSession = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsForm(settings: settings, inSession: inSession)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
