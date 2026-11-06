import Foundation
import DuoCore

@MainActor
final class HostAudioStream {
    private let mute = MacAudioMute(hardware: SystemAudioOutput())
    private weak var transport: SecureChannel?
    private var permitsControl = false
    private var sessionID = UUID()
    private var sourceID: UUID?
    private var outstanding = 0
    private var requestID: UUID?
    private(set) var enabled = false
    private(set) var usesMediaTiming = false

    init() { mute.changed = { [weak self] in self?.sendStatus() } }

    func begin(transport: SecureChannel, permitsControl: Bool, usesMediaTiming: Bool) {
        self.transport = transport
        self.permitsControl = permitsControl
        self.usesMediaTiming = usesMediaTiming
        sendStatus()
    }

    func apply(_ request: AudioControl, to pipeline: HostMediaPipeline?) async {
        let session = sessionID
        let captureChanged = enabled != request.enabled
        enabled = request.enabled
        requestID = request.requestID
        mute.setEnabled(request.enabled && request.muteMac == true && permitsControl)
        do {
            if captureChanged { try await pipeline?.setAudioEnabled(request.enabled) }
            guard session == sessionID else { return }
            sendStatus()
        } catch {
            guard session == sessionID else { return }
            captureFailed()
        }
    }

    func beginCapture(_ id: UUID) { sourceID = id; outstanding = 0 }
    func endCapture(_ id: UUID) {
        guard sourceID == id else { return }
        sourceID = nil; outstanding = 0
    }

    func send(_ frame: AudioFrame, from id: UUID) {
        guard sourceID == id, enabled, outstanding < 6, let transport,
              let payload = try? JSONEncoder().encode(frame) else { return }
        outstanding += 1
        transport.send(.audioFrame, payload: payload) { [weak self] in Task { @MainActor in
            guard let self, self.sourceID == id else { return }
            self.outstanding = max(0, self.outstanding - 1)
        } }
    }

    func captureFailed() {
        enabled = false
        mute.setEnabled(false)
        sendStatus(failed: true)
    }

    func stop() {
        sessionID = UUID(); sourceID = nil
        enabled = false; outstanding = 0; requestID = nil
        usesMediaTiming = false; permitsControl = false; transport = nil
        mute.setEnabled(false)
    }

    private func sendStatus(failed: Bool = false) {
        guard usesMediaTiming, let transport else { return }
        transport.send(.audioStatus, object: AudioStatus(enabled: enabled, failed: failed, requestID: requestID,
            canMuteMac: permitsControl && mute.available, macMuteEnabled: mute.enabled, macMuteFailed: mute.failed))
    }
}
