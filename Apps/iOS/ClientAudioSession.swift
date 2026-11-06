import AVFoundation
import DuoCore

@MainActor
final class ClientAudioSession {
    private var playback = false
    private var microphone = false
    private var appliedMode: Mode = .off
    enum Mode { case off, playback, microphone }
    private let applyMode: (Mode) throws -> Void

    init(apply: ((Mode) throws -> Void)? = nil) {
        self.applyMode = apply ?? Self.applySystemMode
    }

    func setPlayback(_ value: Bool) throws {
        guard value != playback else { return }
        playback = value
        do { try apply() } catch { playback = !value; throw error }
    }

    func setMicrophone(_ value: Bool) throws {
        guard value != microphone else { return }
        microphone = value
        do { try apply() } catch { microphone = !value; throw error }
    }

    private func apply() throws {
        let mode: Mode = microphone ? .microphone : playback ? .playback : .off
        guard mode != appliedMode else { return }
        try applyMode(mode)
        appliedMode = mode
    }

    private static func applySystemMode(_ mode: Mode) throws {
        let session = AVAudioSession.sharedInstance()
        if mode == .microphone {
            let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .mixWithOthers, .allowBluetoothHFP]
            try session.setCategory(.playAndRecord, mode: .default, options: options)
            try session.setPreferredSampleRate(MicrophoneFormat.sampleRate)
            try session.setActive(true)
        } else if mode == .playback {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } else {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }
}
