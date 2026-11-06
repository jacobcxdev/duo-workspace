import AppKit

/// Restores only changes made by this session. Manual unmute takes precedence.
@MainActor
final class MacAudioMute: NSObject {
    private let hardware: any AudioOutputHardware
    private var activeDevice: UInt32?
    private var restoreDevice: UInt32?
    private(set) var enabled = false
    private(set) var failed = false
    var changed: (() -> Void)?

    var available: Bool { hardware.defaultOutput.flatMap { hardware.muteState(of: $0) } != nil }

    init(hardware: any AudioOutputHardware) {
        self.hardware = hardware
        super.init()
        hardware.changed = { [weak self] in self?.hardwareChanged() }
        NotificationCenter.default.addObserver(self, selector: #selector(willTerminate),
            name: NSApplication.willTerminateNotification, object: nil)
    }

    func setEnabled(_ requested: Bool) {
        failed = false
        if !requested {
            enabled = false; activeDevice = nil
            restore()
        } else if !enabled || activeDevice != hardware.defaultOutput {
            restore()
            guard !failed else { enabled = false; activeDevice = nil; return }
            enabled = true
            acquire()
        }
    }

    private func acquire() {
        guard let device = hardware.defaultOutput, let muted = hardware.muteState(of: device) else {
            enabled = false; activeDevice = nil; failed = true; return
        }
        activeDevice = device
        guard !muted else { return }
        do {
            try hardware.setMute(true, on: device)
            restoreDevice = device
        } catch { enabled = false; activeDevice = nil; failed = true }
    }

    private func restore() {
        guard let device = restoreDevice else { return }
        // An output which the user already unmuted is no longer ours to change.
        guard let muted = hardware.muteState(of: device) else { failed = true; return }
        guard muted else { restoreDevice = nil; return }
        do { try hardware.setMute(false, on: device); restoreDevice = nil }
        catch { failed = true } // Retain ownership so another stop can retry.
    }

    private func hardwareChanged() {
        if enabled, activeDevice != hardware.defaultOutput {
            restore()
            if !failed { acquire() }
            else { enabled = false; activeDevice = nil }
        } else if enabled, let device = activeDevice, hardware.muteState(of: device) == false {
            restoreDevice = nil; activeDevice = nil; enabled = false
        }
        changed?()
    }

    @objc private func willTerminate() { setEnabled(false) }
    deinit { NotificationCenter.default.removeObserver(self) }
}
