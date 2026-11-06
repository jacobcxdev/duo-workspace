import Foundation
import DuoCore

enum RecoveryVideoFixture {
    // One black 320x240 frame encoded with VideoToolbox, including its SPS/PPS.
    static func send(to channel: SecureChannel) {
        channel.send(.videoConfiguration, object: VideoConfiguration(width: 320, height: 240,
            sps: Data(base64Encoded: "J2QADaxWgUH5" )!, pps: Data(base64Encoded: "KO48sA==" )!))
        channel.send(.videoFrame, payload: Data(base64Encoded:
            "AAAANQYFLUdWStxcTEM/lO/FETzRQ6gBAAADAAEDAAADAAECAAfpAAsAAAMAAAMAABESDAORKwGAAAAANyW4IB/eCOVM/4LMHptQ27MV8qxm3XtIqvnLaAALS4KnyI4noHvfvQFwAAB0iM96aI/notk94j4=")!)
    }
}
