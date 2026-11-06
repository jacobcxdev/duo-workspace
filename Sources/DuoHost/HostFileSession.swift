import AppKit
import DuoCore

@MainActor
final class HostFileSession {
    let engine = FileTransferEngine()
    private let channel: SecureChannel
    private var picker: NSOpenPanel?
    private var picking: UUID?
    private var pickBudget = TrafficBudget(capacity: 2, perSecond: 1)
    private var closed = false
    private let displayID: () -> CGDirectDisplayID

    init(channel: SecureChannel, displayID: @escaping () -> CGDirectDisplayID) {
        self.channel = channel; self.displayID = displayID
        engine.send = { [weak channel] message in channel?.send(.fileTransfer, object: message) }
        engine.onOffer = { [weak self] in
            guard let self else { return }
            let folder = URL.downloadsDirectory
                .appendingPathComponent("Duo Workspace", isDirectory: true)
            Task { [weak self] in await self?.engine.accept(into: folder) }
        }
    }

    func receive(_ message: FileTransferMessage) async throws {
        guard message.isValid, !closed else { throw FileTransferError.protocolViolation }
        if message.action == .pick {
            guard picker == nil, !engine.state.isBusy, pickBudget.consume(now: ProcessInfo.processInfo.systemUptime) else {
                channel.send(.fileTransfer, object: FileTransferMessage(id: message.id, action: .failed, failure: .busy)); return
            }
            pickFile(id: message.id)
        } else if message.action == .cancel, picking == message.id {
            picker?.cancel(nil); picker = nil; picking = nil
        } else {
            if picker != nil, message.action == .offer {
                channel.send(.fileTransfer, object: FileTransferMessage(id: message.id, action: .failed, failure: .busy)); return
            }
            try await engine.receive(message)
        }
    }

    private func pickFile(id: UUID) {
        let panel = NSOpenPanel()
        panel.title = "Send a file to your device"
        panel.prompt = "Send"
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        picking = id; picker = panel
        if let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID() }) {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - panel.frame.width / 2,
                                         y: screen.visibleFrame.midY - panel.frame.height / 2))
        }
        NSApp.activate()
        panel.begin { [weak self, weak panel] response in
            guard let self, !self.closed, self.picking == id else { return }
            self.picker = nil; self.picking = nil
            guard response == .OK, let url = panel?.url else {
                self.channel.send(.fileTransfer, object: FileTransferMessage(id: id, action: .cancel)); return
            }
            Task { [weak self] in
                guard let self, !self.closed else { return }
                await self.engine.sendFile(url, id: id)
            }
        }
    }

    func close() {
        closed = true; picking = nil
        picker?.cancel(nil); picker = nil
        engine.disconnect()
    }
}
