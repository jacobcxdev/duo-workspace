import SwiftUI
import DuoCore

struct StreamQualityLabel: View {
    let quality: StreamQuality

    var body: some View {
        switch quality {
        case .efficient: Text("Efficient")
        case .balanced: Text("Balanced")
        case .sharp: Text("Sharp")
        case .maximum: Text("Maximum detail")
        }
    }
}
