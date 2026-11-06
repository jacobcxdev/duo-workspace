import Foundation
import Testing
import DuoCore
@testable import DuoWorkspace

@MainActor
struct AudioControlTests {
    @Test func repliesCannotOverwriteANewerSoundChoice() throws {
        let audio = SessionAudio()
        var requests: [AudioControl] = []
        audio.send = { requests.append($0) }
        audio.supportsMacMute = true
        audio.enabled = true
        audio.muteMac = true
        #expect(requests.count == 2)
        let old = try #require(requests[0].requestID)
        let latest = try #require(requests[1].requestID)
        audio.receive(.init(enabled: true, requestID: old, canMuteMac: true, macMuteEnabled: false))
        #expect(audio.muteMac)
        audio.receive(.init(enabled: true, requestID: latest, canMuteMac: true, macMuteEnabled: true))
        #expect(audio.muteMac && requests.count == 2)
        audio.enabled = false
        audio.receive(.init(enabled: false, requestID: requests.last?.requestID, canMuteMac: true, macMuteEnabled: false))
        #expect(audio.muteMac) // The preference survives turning phone audio off.
        audio.enabled = true
        #expect(requests.last?.muteMac == true)
        audio.disconnect()
    }

    @Test func aManualMacUnmuteUpdatesTheControlWithoutSendingItBack() throws {
        let audio = SessionAudio()
        var requests: [AudioControl] = []
        audio.send = { requests.append($0) }
        audio.supportsMacMute = true; audio.enabled = true; audio.muteMac = true
        let count = requests.count
        audio.receive(.init(enabled: true, requestID: requests.last?.requestID, canMuteMac: true, macMuteEnabled: false))
        #expect(!audio.muteMac && requests.count == count && audio.enabled)
        audio.disconnect()
    }

    @Test func legacyAudioMessagesRemainCompatible() throws {
        let request = try JSONDecoder().decode(AudioControl.self, from: Data(#"{"enabled":true}"#.utf8))
        #expect(request.enabled && request.muteMac == nil && request.requestID == nil)
        let reply = try JSONDecoder().decode(AudioStatus.self, from: Data(#"{"enabled":true,"failed":false}"#.utf8))
        #expect(reply.enabled && reply.canMuteMac == nil)
    }
}
