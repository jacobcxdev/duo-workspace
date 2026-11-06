import AVFoundation
import Observation
import DuoCore

@MainActor @Observable
final class SessionAudio {
    var enabled = false {
        didSet {
            guard enabled != oldValue else { return }
            if !enabled { stopPlayback(); deactivate() }
            message = nil
            sendControl()
        }
    }
    var volume: Float = 1 { didSet { player.volume = volume.isFinite ? min(1, max(0, volume)) : 0 } }
    var muteMac = false { didSet { if muteMac != oldValue, enabled, !applyingStatus { message = nil; sendControl() } } }
    var supportsMacMute = false
    private(set) var canMuteMac = false
    private(set) var message: LocalizedStringResource?
    private(set) var receivedPackets = 0
    private(set) var peak: Float = 0
    @ObservationIgnored var send: ((AudioControl) -> Void)?
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let player = AVAudioPlayerNode()
    @ObservationIgnored private var decoder: AACAudioDecoder?
    @ObservationIgnored private var stream: UUID?
    @ObservationIgnored private var lastIndex: UInt64?
    @ObservationIgnored private var queuedFrames = 0
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var videoTime: TimeInterval?
    @ObservationIgnored private var interruption: NSObjectProtocol?
    @ObservationIgnored private var interrupted = false
    @ObservationIgnored private var applyingStatus = false
    @ObservationIgnored private var lastRequestID: UUID?
    @ObservationIgnored private let audioSession: ClientAudioSession

    init(audioSession: ClientAudioSession? = nil) {
        self.audioSession = audioSession ?? ClientAudioSession()
        engine.attach(player)
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                                               object: nil, queue: .main) { [weak self] notification in
            let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor [weak self] in
                self?.interrupted = began
                self?.stopPlayback()
            }
        }
    }

    func sessionReady() { if enabled { sendControl() } }
    func noteVideoTime(_ time: TimeInterval) { videoTime = time }

    func receive(_ frame: AudioFrame) throws {
        guard frame.isValid else { throw WireError.oversized }
        guard enabled, !interrupted else { return }
        if let videoTime, frame.time < videoTime - 0.2 { stopPlayback(); return }
        if stream == frame.stream, let lastIndex, frame.index <= lastIndex { return }
        if stream != frame.stream || lastIndex.map({ frame.index != $0 + 1 }) == true || queuedFrames > 7_200 {
            stopPlayback()
        }
        if decoder == nil {
            let next = try AACAudioDecoder(cookie: frame.cookie)
            decoder = next; stream = frame.stream
            engine.connect(player, to: engine.mainMixerNode, format: next.format)
        }
        guard let decoder else { return }
        let pcm = try decoder.decode(frame)
        lastIndex = frame.index
        guard pcm.frameLength > 0 else { return }
        if !engine.isRunning {
            try audioSession.setPlayback(true)
            try engine.start()
        }
        receivedPackets += 1
        if let samples = pcm.floatChannelData {
            peak = (0..<Int(pcm.frameLength)).reduce(Float(0)) { max($0, abs(samples[0][$1])) }
        }
        let count = Int(pcm.frameLength), expected = generation
        queuedFrames += count
        player.scheduleBuffer(pcm, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == expected else { return }
                self.queuedFrames = max(0, self.queuedFrames - count)
            }
        }
        if !player.isPlaying { player.play() }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--sharing-diagnostics"), receivedPackets == 1 || receivedPackets % 50 == 0 {
            NSLog("[DuoAudio] packets=\(receivedPackets) peak=\(peak) queuedFrames=\(queuedFrames) playing=\(player.isPlaying) videoDelta=\(videoTime.map { frame.time - $0 } ?? 0)")
        }
        #endif
    }

    func receive(_ status: AudioStatus) {
        if let available = status.canMuteMac { canMuteMac = available }
        if let requestID = status.requestID, requestID != lastRequestID { return }
        if status.requestID != nil, enabled, let managed = status.macMuteEnabled {
            applyingStatus = true; muteMac = managed; applyingStatus = false
        }
        if status.macMuteFailed == true {
            message = "Couldn't change the Mac's sound output. Use its sound controls."
        }
        if status.failed {
            enabled = false
            message = "Couldn't start Mac audio. Try turning it on again."
        }
    }

    func pause() { stopPlayback(); videoTime = nil }
    func disconnect() {
        send = nil; lastRequestID = nil; supportsMacMute = false; canMuteMac = false
        pause(); deactivate(); receivedPackets = 0; peak = 0; message = nil
    }

    private func sendControl() {
        guard let send else { return }
        let id = UUID(); lastRequestID = id
        send(AudioControl(enabled: enabled, muteMac: supportsMacMute ? muteMac : nil, requestID: id))
    }

    private func deactivate() {
        try? audioSession.setPlayback(false)
    }

    private func stopPlayback() {
        generation += 1; queuedFrames = 0
        player.stop(); engine.stop()
        decoder = nil; stream = nil; lastIndex = nil
    }

    isolated deinit { if let interruption { NotificationCenter.default.removeObserver(interruption) } }
}
