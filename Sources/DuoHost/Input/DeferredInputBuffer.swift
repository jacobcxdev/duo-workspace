import DuoCore

struct DeferredInputBuffer {
    private var entries: [(event: InputEvent, bytes: Int)] = []
    private var byteCount = 0

    mutating func append(_ event: InputEvent, payloadSize: Int) -> Bool {
        // Preserve click/text/release order so text keeps its original target.
        if event.kind == .releaseAll, entries.last?.event.kind == .releaseAll { return true }
        guard payloadSize >= 0, entries.count < 256, payloadSize <= 65_536 - byteCount else { return false }
        entries.append((event, payloadSize)); byteCount += payloadSize
        return true
    }

    mutating func take() -> [InputEvent] {
        let events = entries.map(\.event)
        removeAll()
        return events
    }

    mutating func removeAll() { entries.removeAll(); byteCount = 0 }
}
