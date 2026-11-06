import CoreAudio

/// Core Audio owns the callback queue; removing a listener is thread-safe.
final class AudioPropertyObservation: @unchecked Sendable {
    private let object: AudioObjectID
    private var address: AudioObjectPropertyAddress
    private let callback: AudioObjectPropertyListenerBlock

    init?(object: AudioObjectID, address: AudioObjectPropertyAddress, changed: @escaping @Sendable () -> Void) {
        self.object = object; self.address = address
        callback = { _, _ in changed() }
        guard AudioObjectAddPropertyListenerBlock(object, &self.address, nil, callback) == noErr else { return nil }
    }

    deinit { AudioObjectRemovePropertyListenerBlock(object, &address, nil, callback) }
}
