import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    let files: SessionFiles
    var showMac: () -> Void
    var chooseFileOnMac: () -> Void
    @State private var importing = false
    @State private var importFailed = false

    var body: some View {
        Form {
            if !files.ready {
                Section {
                    if files.connecting { ProgressView("Connecting for files…") }
                    else { Button("Connect for files", action: files.connect) }
                }
            }
            if files.choosingOnMac {
                Section {
                    Text("Select a file in the Mac dialog, then choose Send.")
                    Button("Show Mac", action: showMac)
                    Button("Cancel selection", role: .cancel, action: files.cancel)
                }
            }
            FileTransferSection(files: files, importFailed: importFailed)
            Section {
                Button("Send file to Mac", systemImage: "square.and.arrow.up") { importing = true }
                    .accessibilityIdentifier("files.send")
                Button("Get file from Mac", systemImage: "square.and.arrow.down", action: chooseFileOnMac)
                    .accessibilityIdentifier("files.chooseOnMac")
            } footer: { Text("Send to Downloads/Duo Workspace. Get files by choosing them on your Mac.") }
            .disabled(!files.ready || files.transfer.state.isBusy || files.choosingOnMac)
            if !files.receivedFiles.isEmpty {
                Section {
                    ForEach(files.receivedFiles) { file in
                        ShareLink(item: file.url) { Label(file.name, systemImage: "square.and.arrow.up") }
                            .accessibilityLabel("Save or share \(file.name)")
                            .accessibilityIdentifier("files.save")
                    }
                    .onDelete(perform: files.removeReceived)
                } header: { Text("Received files") }
                footer: { Text("Choose a file to save or share it. Swipe to remove its temporary copy.") }
            }
        }
        .navigationTitle("Files")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(VisibleSessionNavigationBar())
        .onAppear(perform: files.connect)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
            switch result {
            case .success(let url): importFailed = false; files.sendFile(url)
            case .failure(let error):
                importFailed = (error as NSError).code != NSUserCancelledError
            }
        }
    }
}
