import Foundation
import Testing
@testable import DuoHost

@MainActor
struct MacAudioMuteTests {
    @Test func restoresOnlyMuteChangesMadeByTheSession() {
        let hardware = TestAudioOutput(muted: false)
        let mute = MacAudioMute(hardware: hardware)
        mute.setEnabled(true)
        #expect(mute.enabled && hardware.values[1] == true)
        mute.setEnabled(true)
        #expect(hardware.writes.count == 1)
        mute.setEnabled(false)
        #expect(!mute.enabled && hardware.values[1] == false && hardware.writes.count == 2)

        let alreadyMuted = TestAudioOutput(muted: true)
        let preserved = MacAudioMute(hardware: alreadyMuted)
        preserved.setEnabled(true); preserved.setEnabled(false)
        #expect(alreadyMuted.values[1] == true && alreadyMuted.writes.isEmpty)
    }

    @Test func manualChangesTakeOverFromTheSession() {
        let hardware = TestAudioOutput(muted: false)
        let mute = MacAudioMute(hardware: hardware)
        mute.setEnabled(true)
        hardware.values[1] = false
        hardware.changed?()
        #expect(!mute.enabled)
        hardware.values[1] = true // The user later muted it themselves.
        hardware.changed?()
        mute.setEnabled(false)
        #expect(hardware.values[1] == true && hardware.writes.count == 1)
    }

    @Test func switchingOutputsRestoresThePreviousDevice() {
        let hardware = TestAudioOutput(muted: false)
        hardware.values[2] = false
        let mute = MacAudioMute(hardware: hardware)
        mute.setEnabled(true)
        hardware.defaultOutput = 2
        hardware.changed?()
        #expect(hardware.values[1] == false && hardware.values[2] == true && mute.enabled)
        mute.setEnabled(false)
        #expect(hardware.values[2] == false)
    }

    @Test func unsupportedAndFailedRestorationRemainVisibleAndRetryable() {
        let hardware = TestAudioOutput(muted: false)
        let mute = MacAudioMute(hardware: hardware)
        hardware.defaultOutput = 99
        mute.setEnabled(true)
        #expect(!mute.enabled && mute.failed && !mute.available && hardware.writes.isEmpty)
        hardware.defaultOutput = 1
        mute.setEnabled(true)
        hardware.rejectWrites = true
        mute.setEnabled(false)
        #expect(mute.failed && hardware.values[1] == true)
        hardware.rejectWrites = false
        mute.setEnabled(false)
        #expect(!mute.failed && hardware.values[1] == false)
    }
}

@MainActor private final class TestAudioOutput: AudioOutputHardware {
    var changed: (() -> Void)?
    var defaultOutput: UInt32? = 1
    var values: [UInt32: Bool]
    var writes: [(UInt32, Bool)] = []
    var rejectWrites = false
    init(muted: Bool) { values = [1: muted] }
    func muteState(of device: UInt32) -> Bool? { values[device] }
    func setMute(_ muted: Bool, on device: UInt32) throws {
        if rejectWrites { throw CocoaError(.fileWriteNoPermission) }
        values[device] = muted; writes.append((device, muted))
    }
}
