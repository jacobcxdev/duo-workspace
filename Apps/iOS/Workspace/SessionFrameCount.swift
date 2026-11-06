import SwiftUI

struct SessionFrameCount: View {
    let model: SessionModel

    var body: some View {
        LabeledContent("Frames received") { Text(model.receivedFrames, format: .number).monospacedDigit() }
    }
}
