import SwiftUI
import DuoHost

@main
struct DuoHostApp: App {
    @State private var host = HostController()

    var body: some Scene {
        WindowGroup("Duo Workspace Host") {
            HostView(host: host).frame(minWidth: 460, minHeight: 560)
        }
        .defaultSize(width: 520, height: 680)
        MenuBarExtra("Duo Workspace", systemImage: "display.2") {
            Text(host.status)
            Button(host.sharing ? "Stop Sharing" : "Start Sharing") {
                host.sharing ? host.stop() : host.start()
            }.disabled(!host.access.isReady)
            Divider()
            Button("Quit Duo Workspace") { host.stop(); NSApplication.shared.terminate(nil) }
        }
    }
}
