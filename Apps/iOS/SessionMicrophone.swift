import AVFoundation
import Observation
import DuoCore

@MainActor @Observable
final class SessionMicrophone {
    var enabled = false { didSet { if enabled != oldValue { enabled ? begin() : stop() } } }
    var supported = false
    private(set) var available = false
    private(set) var sending = false
    private(set) var peak: Float = 0
    private(set) var sentFrames = 0
    private(set) var message: LocalizedStringResource?
    @ObservationIgnored var sendControl: ((MicrophoneControl) -> Bool)?
    @ObservationIgnored var sendFrame: ((MicrophoneFrame, @escaping @Sendable () -> Void) -> Bool)?
    @ObservationIgnored private let audioSession: ClientAudioSession
    @ObservationIgnored private var capture: (any MicrophoneCapturing)?
    @ObservationIgnored private let permission: () async -> Bool
    @ObservationIgnored private let makeCapture: (@escaping MicrophonePacketHandler) -> any MicrophoneCapturing
    @ObservationIgnored private var startTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var requestID: UUID?
    @ObservationIgnored private var stream: UUID?
    @ObservationIgnored private var index: UInt64 = 0
    @ObservationIgnored private var interruption: NSObjectProtocol?

    init(audioSession: ClientAudioSession, permission: (() async -> Bool)? = nil,
         makeCapture: ((@escaping MicrophonePacketHandler) -> any MicrophoneCapturing)? = nil) {
        self.audioSession = audioSession
        self.permission = permission ?? {
            await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
        }
        self.makeCapture = makeCapture ?? { MicrophoneCapture(received: $0) }
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            if (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue {
                Task { @MainActor in self?.enabled = false }
            }
        }
    }

    func connected(supported: Bool) {
        self.supported = supported
        if supported {
            let id = UUID(); requestID = id
            _ = sendControl?(MicrophoneControl(enabled: false, requestID: id))
        }
    }

    private func begin() {
        guard supported, available else { enabled = false; return }
        message = nil; generation = UUID(); let token = generation
        startTask = Task { [weak self] in
            guard let permission = self?.permission else { return }
            let allowed = await permission()
            guard let self, self.generation == token, self.enabled, !Task.isCancelled else { return }
            guard allowed else {
                self.enabled = false
                self.message = "Allow Microphone access for Duo Workspace in Settings."
                return
            }
            let id = UUID(); self.requestID = id
            if self.sendControl?(MicrophoneControl(enabled: true, requestID: id)) != true {
                self.enabled = false; self.message = "Reconnect to your Mac to use the microphone."
            }
        }
    }

    func receive(_ status: MicrophoneStatus) {
        guard status.isValid else { return }
        available = status.available
        if let reply = status.requestID, reply != requestID { return }
        if !status.enabled {
            if enabled { enabled = false }
            if let failure = status.failure { message = text(for: failure) }
            return
        }
        guard enabled, let stream = status.stream, self.stream != stream else { return }
        self.stream = stream; index = 0; let token = generation
        do {
            try audioSession.setMicrophone(true)
            let capture = makeCapture { @Sendable [weak self] data, peak, completion in
                Task { @MainActor in
                    guard let self, self.generation == token, self.enabled, self.sending, let stream = self.stream else { completion(); return }
                    self.peak = peak; self.index &+= 1
                    if self.sendFrame?(MicrophoneFrame(stream: stream, index: self.index, samples: data), completion) == true {
                        self.sentFrames += 1
                    } else { completion() }
                }
            }
            self.capture = capture
            try capture.start(); sending = true
        } catch {
            #if DEBUG
            NSLog("[DuoMicrophone] Capture start failed: %@", String(describing: error))
            #endif
            enabled = false; message = "Couldn't start the microphone. Try turning it on again."
        }
    }

    private func stop() {
        generation = UUID(); startTask?.cancel(); startTask = nil
        capture?.stop(); capture = nil; sending = false; stream = nil; peak = 0
        try? audioSession.setMicrophone(false)
        let id = UUID(); requestID = id
        if supported { _ = sendControl?(MicrophoneControl(enabled: false, requestID: id)) }
    }

    func disconnect() {
        if enabled { enabled = false } else { stop() }
        sendControl = nil; sendFrame = nil; supported = false; available = false
        sentFrames = 0; message = nil
    }

    private func text(for failure: MicrophoneStatus.Failure) -> LocalizedStringResource {
        switch failure {
        case .deviceMissing: "Install Duo Microphone from the Mac host, then try again."
        case .deviceBusy: "Duo Microphone is in use. Stop the other session, then try again."
        case .controlRequired: "This device needs control access to send microphone audio."
        case .streamFailed: "Microphone audio stopped. Turn it on again to retry."
        }
    }

    isolated deinit { if let interruption { NotificationCenter.default.removeObserver(interruption) } }
}
