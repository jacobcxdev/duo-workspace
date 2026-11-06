import SwiftUI
import DuoCore

struct MacsView: View {
    @Bindable var model: SessionModel
    @State private var editor: HostEditorRoute?
    @State private var showsSettings = false
    @State private var forgetCandidate: HostProfile?
    @State private var showsForget = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if model.library.hosts.isEmpty {
                    LibraryEmptyView(add: addMac)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(model.library.hosts) { host in
                            MacCard(host: host, connect: { model.connect(host, mode: $0) },
                                    edit: { editor = HostEditorRoute(host: host) },
                                    forget: { forgetCandidate = host; showsForget = true })
                        }
                    } header: { Text("Saved Macs") }
                    footer: { Text("Start sharing in Duo Workspace Host on your Mac, then choose a workspace.") }
                }
            }
            .listSectionSpacing(.custom(20))
            .navigationTitle("Duo Workspace")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Mac", systemImage: "plus", action: addMac)
                        .accessibilityIdentifier("library.add")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showsSettings = true }
                }
            }
            .sheet(item: $editor, onDismiss: model.startPreparedPairing) { route in HostEditorView(model: model, host: route.host) }
            .sheet(isPresented: $showsSettings) { SettingsView(settings: model.settings) }
            .fullScreenCover(isPresented: $model.presentsSession, onDismiss: model.disconnect) {
                RemoteSessionView(model: model)
            }
            .confirmationDialog("Forget this Mac?", isPresented: $showsForget, titleVisibility: .visible) {
                Button("Forget Mac", role: .destructive, action: forgetMac)
            } message: { Text("Removes this saved Mac. To revoke this device’s access too, choose Revoke access on the Mac.") }
            .onChange(of: model.libraryError) { _, message in errorMessage = message }
            .alert("Couldn’t save changes", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func addMac() { editor = HostEditorRoute(host: nil) }
    private func forgetMac() {
        guard let host = forgetCandidate else { return }
        do { try model.library.remove(host); forgetCandidate = nil }
        catch { errorMessage = "Couldn’t remove the saved Mac. Unlock this device and try again." }
    }
}

#Preview { MacsView(model: SessionModel(defaults: UserDefaults(suiteName: "DuoPreview")!)) }
