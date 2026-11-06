import Foundation
import Observation
import DuoCore

@MainActor @Observable
final class SessionDisplay {
    private(set) var mode: WorkspaceMode = .control
    private(set) var quality: StreamQuality = .balanced
    private(set) var qualityLimitedByHost = false
    private(set) var desktop: DesktopSize?
    private(set) var resizing = false
    private(set) var viewportContext: WorkspaceViewportContext?
    private(set) var displayInfo: NativeDisplayInfo?
    @ObservationIgnored var sendHello: ((ClientHello) -> Void)?
    @ObservationIgnored var sendResize: ((DesktopResizeRequest) -> Void)?
    @ObservationIgnored var willResize: (() -> Void)?
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let delay: (Duration) async throws -> Void
    @ObservationIgnored private var active = false
    @ObservationIgnored private var authorized = false
    @ObservationIgnored private var videoReady = false
    @ObservationIgnored private var displayInfoContext: WorkspaceViewportContext?
    @ObservationIgnored private var viewport: DesktopSize?
    @ObservationIgnored private var viewportSize: CGSize?
    @ObservationIgnored private var lastRequestedDesktop: DesktopSize?
    @ObservationIgnored private var supportsAdaptiveDisplay = false
    @ObservationIgnored private var requestedQuality = StreamQuality.balanced
    @ObservationIgnored private var pendingDisplayMatch = false
    @ObservationIgnored private var waitingForViewport = false
    @ObservationIgnored private var helloSent = false
    @ObservationIgnored private var transportGeneration: UInt64 = 0
    @ObservationIgnored private var resizeRevision: UInt64 = 0
    @ObservationIgnored private var viewportTask: Task<Void, Never>?
    @ObservationIgnored private var helloTask: Task<Void, Never>?

    init(settings: AppSettings, delay: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.settings = settings
        self.delay = delay
    }

    func begin(mode: WorkspaceMode, quality: StreamQuality) {
        active = true
        self.mode = mode
        self.quality = quality
        requestedQuality = quality
    }

    func connectionApproved(adaptive: Bool, maximumDetail: Bool) {
        authorized = true
        supportsAdaptiveDisplay = adaptive
        quality = requestedQuality
        qualityLimitedByHost = quality == .maximum && !maximumDetail
        if qualityLimitedByHost { quality = .sharp }
        if adaptive && mode == .extend && (viewport == nil || needsDisplayMeasurement) {
            waitingForViewport = true
            let generation = transportGeneration
            let delay = self.delay
            helloTask = Task { [weak self] in
                do { try await delay(.seconds(1)) } catch { return }
                guard let self, !Task.isCancelled, self.transportGeneration == generation, self.waitingForViewport else { return }
                self.sendInitialHello(allowFallback: true)
            }
        } else { sendInitialHello() }
    }

    func setVideoReady(_ ready: Bool) {
        videoReady = ready
        if ready { scheduleViewportUpdate() }
        else { viewportTask?.cancel(); viewportTask = nil }
    }

    func receive(_ update: DesktopState) throws {
        guard authorized, mode == .extend, supportsAdaptiveDisplay,
              update.desktop.isValid, update.revision <= resizeRevision else { throw IdentityError.invalidIdentity }
        desktop = update.desktop
        resizing = !update.ready
        reportLayoutDiagnostic("reply revision=\(update.revision) desktop=\(update.desktop.width)x\(update.desktop.height) scale=\(update.desktop.scale) ready=\(update.ready) accepted=\(update.accepted)")
    }

    func resetTransport() {
        transportGeneration &+= 1
        viewportTask?.cancel(); viewportTask = nil
        helloTask?.cancel(); helloTask = nil
        authorized = false; videoReady = false
        waitingForViewport = false; helloSent = false; supportsAdaptiveDisplay = false
        resizeRevision = 0; lastRequestedDesktop = nil
        desktop = nil; resizing = false; qualityLimitedByHost = false
    }

    func disconnect() {
        resetTransport()
        active = false
        viewport = nil; viewportSize = nil; viewportContext = nil
        displayInfo = nil; displayInfoContext = nil; pendingDisplayMatch = false
    }

    func reportViewport(_ size: CGSize) {
        guard active, let next = plannedDesktop(size) else { return }
        viewportSize = size
        guard next != viewport else { return }
        viewport = next
        reportLayoutDiagnostic("viewport=\(size.width)x\(size.height) desktop=\(next.width)x\(next.height)")
        if waitingForViewport { sendInitialHello() }
        else { scheduleViewportUpdate() }
    }

    func selectViewport(_ context: WorkspaceViewportContext) {
        guard active else { return }
        viewportContext = context
        reportLayoutDiagnostic("layout=\(context.layout) root=\(context.rootSize)")
    }

    func reportViewport(_ size: CGSize, context: WorkspaceViewportContext) {
        guard viewportContext == context else { return }
        reportViewport(size)
    }

    func refreshDesktopShape() {
        if mode == .extend, settings.desktopSizing == .matchDisplay, settings.matchedDisplay?.isValid != true {
            settings.matchedDisplay = currentDisplayInfo?.pixels
        }
        if let viewportSize { reportViewport(viewportSize) }
    }

    func refreshDesktopSizing() {
        pendingDisplayMatch = false
        if mode == .extend, settings.desktopSizing == .matchDisplay { settings.matchedDisplay = currentDisplayInfo?.pixels }
        if let viewportSize { reportViewport(viewportSize) }
    }

    func updateDisplayMatch() {
        guard mode == .extend, settings.desktopSizing == .matchDisplay else { return }
        guard let currentDisplayInfo else { pendingDisplayMatch = true; return }
        pendingDisplayMatch = false
        settings.matchedDisplay = currentDisplayInfo.pixels
        if let viewportSize { reportViewport(viewportSize) }
    }

    func reportViewport(_ size: CGSize, display info: NativeDisplayInfo, context: WorkspaceViewportContext) {
        guard active, viewportContext == context, info.isValid else { return }
        if displayInfo != info {
            reportLayoutDiagnostic("display=\(info.pixels.width)x\(info.pixels.height) points=\(info.pointWidth)x\(info.pointHeight) nativeScale=\(info.nativeScale)")
        }
        displayInfo = info
        displayInfoContext = context
        if mode == .extend, settings.desktopSizing == .matchDisplay,
           pendingDisplayMatch || (settings.desktopShape != .automatic && settings.matchedDisplay?.isValid != true) {
            settings.matchedDisplay = info.pixels
            pendingDisplayMatch = false
        }
        reportViewport(size)
        if waitingForViewport { sendInitialHello() }
    }

    private var needsDisplayMeasurement: Bool {
        settings.desktopSizing == .matchDisplay
            && (pendingDisplayMatch || (settings.desktopShape == .automatic ? currentDisplayInfo == nil : settings.matchedDisplay?.isValid != true))
    }

    var currentDisplayInfo: NativeDisplayInfo? { displayInfoContext == viewportContext ? displayInfo : nil }

    private func plannedDesktop(_ size: CGSize, allowFallback: Bool = false) -> DesktopSize? {
        guard allowFallback || !needsDisplayMeasurement else { return nil }
        return settings.desktopSizing.desktop(shape: settings.desktopShape, viewportWidth: size.width, viewportHeight: size.height,
                                              display: currentDisplayInfo, matchedDisplay: settings.matchedDisplay)
    }

    private func sendInitialHello(allowFallback: Bool = false) {
        guard authorized, !helloSent else { return }
        guard allowFallback || mode != .extend || !supportsAdaptiveDisplay || !needsDisplayMeasurement else { return }
        waitingForViewport = false; helloTask?.cancel(); helloTask = nil
        let fallback = plannedDesktop(CGSize(width: 800, height: 600), allowFallback: true)
        let target = mode == .extend && supportsAdaptiveDisplay ? (viewport ?? fallback) : nil
        let dimensions = target.map { StreamDimensions.forDesktop($0, quality: quality) }
        lastRequestedDesktop = target; helloSent = true
        var hello = ClientHello(mode: mode, width: dimensions?.width ?? quality.width,
            height: dimensions?.height ?? quality.height, quality: quality, desktop: target,
            supportsCaptureRecovery: true)
        hello.supportsMediaTiming = true
        sendHello?(hello)
    }

    private func scheduleViewportUpdate() {
        viewportTask?.cancel()
        guard videoReady, helloSent, supportsAdaptiveDisplay, mode == .extend,
              let next = viewport, next != lastRequestedDesktop else { return }
        let generation = transportGeneration
        let delay = self.delay
        viewportTask = Task { [weak self] in
            do { try await delay(.milliseconds(350)) } catch { return }
            guard let self, !Task.isCancelled, self.transportGeneration == generation, self.authorized,
                  self.videoReady, self.viewport == next, self.lastRequestedDesktop != next else { return }
            self.willResize?()
            self.resizeRevision &+= 1
            self.lastRequestedDesktop = next
            self.reportLayoutDiagnostic("request revision=\(self.resizeRevision) desktop=\(next.width)x\(next.height)")
            self.sendResize?(DesktopResizeRequest(revision: self.resizeRevision, desktop: next))
        }
    }

    private func reportLayoutDiagnostic(_ value: String) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--layout-diagnostics") {
            try? FileHandle.standardOutput.write(contentsOf: Data("DuoDesktop \(value)\n".utf8))
        }
        #endif
    }

}
