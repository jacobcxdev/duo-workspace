import CoreAudio
import Foundation

@MainActor
final class SystemAudioOutput: AudioOutputHardware {
    var changed: (() -> Void)?
    private var routeObservation: AudioPropertyObservation?
    private var muteObservation: AudioPropertyObservation?
    private var observedDevice: AudioObjectID?

    init() {
        routeObservation = AudioPropertyObservation(object: AudioObjectID(kAudioObjectSystemObject),
            address: Self.defaultAddress) { [weak self] in Task { @MainActor in self?.updateObservation(); self?.changed?() } }
        updateObservation()
    }

    var defaultOutput: UInt32? {
        var address = Self.defaultAddress
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else { return nil }
        return device
    }

    func muteState(of device: UInt32) -> Bool? {
        var address = Self.muteAddress
        var settable = DarwinBoolean(false)
        guard AudioObjectHasProperty(device, &address),
              AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value != 0
    }

    func setMute(_ muted: Bool, on device: UInt32) throws {
        guard muteState(of: device) != nil else { throw CocoaError(.featureUnsupported) }
        var address = Self.muteAddress
        var value: UInt32 = muted ? 1 : 0
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        guard status == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    private func updateObservation() {
        let device = defaultOutput
        guard observedDevice != device else { return }
        observedDevice = device; muteObservation = nil
        if let device {
            muteObservation = AudioPropertyObservation(object: device, address: Self.muteAddress) { [weak self] in
                Task { @MainActor in self?.changed?() }
            }
        }
    }

    private static var defaultAddress: AudioObjectPropertyAddress {
        .init(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
    private static var muteAddress: AudioObjectPropertyAddress {
        .init(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    }
}
