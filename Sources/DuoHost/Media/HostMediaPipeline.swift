import Foundation
import CoreGraphics
import DuoCore

@MainActor
final class HostMediaPipeline {
    struct Configuration {
        let displayID: CGDirectDisplayID
        let width: Int
        let height: Int
        let desktop: DesktopSize?
        let quality: StreamQuality
    }

    typealias StartupError = MediaDeliveryLifetime.StartupError

    let configuration: Configuration
    var onFailure: ((CaptureFailure) -> Void)?
    private let transport: SecureChannel
    private let audio: HostAudioStream
    private let id = UUID()
    private var capture: CaptureEngine?
    private var encoder: H264Encoder?
    private var outstanding = false
    private let lifetime = MediaDeliveryLifetime()
    private var retired: Bool { !lifetime.isActive }

    init(configuration: Configuration, transport: SecureChannel, audio: HostAudioStream) {
        self.configuration = configuration; self.transport = transport; self.audio = audio
    }

    func start() async throws {
        guard !retired, capture == nil else { throw CancellationError() }
        let encoder = try H264Encoder(width: configuration.width, height: configuration.height, bitRate: configuration.quality.bitRate)
        self.encoder = encoder
        encoder.onDiscard = { [weak self] in Task { @MainActor in
            guard let self, !self.retired else { return }
            self.outstanding = false
        } }
        encoder.onOutput = { [weak self] frame in Task { @MainActor in
            guard let self, !self.retired else { return }
            if let config = frame.configuration { self.transport.send(.videoConfiguration, object: config) }
            let timed = self.audio.usesMediaTiming
            let payload = timed ? TimedVideoFrame(time: frame.time, data: frame.data).encoded() : frame.data
            self.transport.send(timed ? .timedVideoFrame : .videoFrame, payload: payload) { [weak self] in Task { @MainActor in
                guard let self, !self.retired else { return }
                self.outstanding = false
            } }
            self.lifetime.firstFrame()
        } }
        let capture = CaptureEngine()
        self.capture = capture
        audio.beginCapture(id)
        capture.onAudio = { [weak self] frame in Task { @MainActor in
            guard let self, !self.retired else { return }
            self.audio.send(frame, from: self.id)
        } }
        capture.onAudioError = { [weak self] in Task { @MainActor in
            guard let self, !self.retired, self.audio.enabled else { return }
            self.audio.captureFailed()
            try? await self.setAudioEnabled(false)
        } }
        capture.onFrame = { [weak self, weak encoder] buffer, time in Task { @MainActor in
            guard let self, !self.retired, !self.outstanding, let encoder else { return }
            self.outstanding = true; encoder.encode(buffer, time: time)
        } }
        capture.onError = { [weak self] failure in Task { @MainActor in
            guard let self, !self.retired else { return }
            self.lifetime.fail(failure)
            self.onFailure?(failure)
        } }
        let expected = configuration.desktop.map { CGSize(width: $0.width, height: $0.height) }
        try await capture.start(displayID: configuration.displayID, width: configuration.width,
            height: configuration.height, expectedLogicalSize: expected, audioEnabled: audio.enabled)
        guard !retired else { await capture.stop(); throw CancellationError() }
    }

    func setAudioEnabled(_ enabled: Bool) async throws {
        guard !retired else { throw CancellationError() }
        try await capture?.setAudioEnabled(enabled)
    }

    func waitForFirstFrame(until deadline: TimeInterval) async throws {
        try await lifetime.waitForFirstFrame(until: deadline)
    }

    func retire() {
        guard !retired else { return }
        lifetime.retire(); onFailure = nil
        audio.endCapture(id)
    }

    func stop() async {
        retire()
        let previousCapture = capture, previousEncoder = encoder
        capture = nil; encoder = nil; outstanding = false
        await lifetime.finish {
            await previousCapture?.stop()
            previousEncoder?.finish()
        }
    }
}
