import Foundation
import Observation
import UIKit
import DuoCore

@MainActor @Observable
final class SessionFiles {
    let transfer = FileTransferEngine()
    private(set) var ready = false
    private(set) var connecting = false
    private(set) var choosingOnMac = false
    private(set) var message: LocalizedStringResource?
    private(set) var receivedFiles: [ReceivedFile] = []
    @ObservationIgnored var makeChannel: (() throws -> SecureChannel)?
    @ObservationIgnored private var channel: SecureChannel?
    @ObservationIgnored private var health: ConnectionHealth?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var pickerTimeout: Task<Void, Never>?
    @ObservationIgnored private var pickID: UUID?

    func connect() {
        guard channel == nil, let makeChannel else { return }
        message = nil; connecting = true
        do {
            let channel = try makeChannel()
            self.channel = channel
            health = ConnectionHealth(now: ProcessInfo.processInfo.systemUptime)
            channel.onReadyAsync = { @MainActor [weak self, weak channel] in
                guard let self, let channel, self.channel === channel else { return }
                channel.send(.authorize, object: AuthorizationRequest(deviceName: UIDevice.current.name, purpose: .files))
            }
            channel.onPacketAsync = { @MainActor [weak self, weak channel] packet in
                guard let self, let channel, self.channel === channel else { return }
                await self.receive(packet, channel: channel)
            }
            channel.onFailure = { [weak self, weak channel] _ in Task { @MainActor in
                guard let self, let channel, self.channel === channel else { return }
                self.close(); self.message = "File connection ended. Reconnect to try again."
            } }
            channel.onAuthenticationFailure = { [weak self, weak channel] in Task { @MainActor in
                guard let self, let channel, self.channel === channel else { return }
                self.close(); self.message = "Couldn't verify the file connection. Check the saved Mac."
            } }
            channel.start()
            timer = Task { [weak self, weak channel] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(3)) } catch { return }
                    guard let self, let channel, self.channel === channel else { return }
                    let now = ProcessInfo.processInfo.systemUptime
                    if self.health?.isExpired(now: now, timeout: 15) == true {
                        self.close(); self.message = "Your Mac stopped responding. Reconnect to transfer files."; return
                    }
                    if let ping = self.health?.ping(now: now) { channel.send(.ping, payload: ping) }
                }
            }
        } catch { close(); message = "Couldn't open the file connection. Reconnect to try again." }
    }

    private func receive(_ packet: Packet, channel: SecureChannel) async {
        do {
            switch packet.kind {
            case .authorization:
                let result = try JSONDecoder().decode(AuthorizationResult.self, from: packet.payload)
                guard result.state == .approved, !ready else {
                    close(); message = "Your Mac declined the file connection. Check this device's access."; return
                }
                ready = true; connecting = false
                transfer.send = { [weak channel] in channel?.send(.fileTransfer, object: $0) }
            case .fileTransfer:
                guard ready else { throw FileTransferError.protocolViolation }
                let reply = try JSONDecoder().decode(FileTransferMessage.self, from: packet.payload)
                guard reply.isValid else { throw FileTransferError.protocolViolation }
                if reply.id == pickID {
                    choosingOnMac = false; pickID = nil; pickerTimeout?.cancel()
                    if reply.action == .cancel { message = "File selection cancelled."; return }
                    if reply.action == .failed { message = "Couldn't choose a file on the Mac. Try again."; return }
                }
                try await transfer.receive(reply)
                if reply.action == .finish, transfer.state == .completed,
                   let url = transfer.receivedURL, !receivedFiles.contains(where: { $0.url == url }) {
                    receivedFiles.append(ReceivedFile(url: url))
                }
            case .pong: health?.acknowledge(packet.payload, now: ProcessInfo.processInfo.systemUptime)
            default: throw FileTransferError.protocolViolation
            }
        } catch { close(); message = "Couldn't read a file-transfer message. Reconnect to try again." }
    }

    func sendFile(_ url: URL) {
        guard ready, !transfer.state.isBusy, !choosingOnMac else { return }
        message = nil
        Task { [weak self] in
            guard let self else { return }
            await self.transfer.sendFile(url)
        }
    }

    @discardableResult
    func chooseOnMac() -> Bool {
        guard ready else { message = "File connection ended. Reconnect to try again."; return false }
        guard !transfer.state.isBusy, !choosingOnMac else { return false }
        let id = UUID(); pickID = id; choosingOnMac = true; message = nil
        channel?.send(.fileTransfer, object: FileTransferMessage(id: id, action: .pick))
        pickerTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(120)) } catch { return }
            guard let self, self.pickID == id else { return }
            self.cancel(); self.message = "File selection timed out. Try again."
        }
        return true
    }

    func receiveFile() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DuoReceived", isDirectory: true)
        Task { [weak self] in await self?.transfer.accept(into: directory) }
    }

    func cancel() {
        if let pickID { channel?.send(.fileTransfer, object: FileTransferMessage(id: pickID, action: .cancel)) }
        pickID = nil; choosingOnMac = false; pickerTimeout?.cancel()
        transfer.cancel()
    }

    func close() {
        cancel(); transfer.disconnect()
        channel?.finish(); channel = nil
        timer?.cancel(); timer = nil
        ready = false; connecting = false; health = nil
    }

    func disconnect() { close(); makeChannel = nil; message = nil }
    func removeReceived(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where receivedFiles.indices.contains(index) {
            do {
                try FileManager.default.removeItem(at: receivedFiles[index].url)
                receivedFiles.remove(at: index)
            } catch { message = "Couldn't remove that download. Try again." }
        }
    }
}
