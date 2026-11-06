import SwiftUI
import DuoCore

struct DesktopShapePicker: View {
    @Binding var selection: DesktopShape

    var body: some View {
        Picker("Desktop shape", selection: $selection) {
            Text("Automatic").tag(DesktopShape.automatic)
            Section("Landscape") {
                Text("16:10").tag(DesktopShape.landscape16x10)
                Text("16:9").tag(DesktopShape.landscape16x9)
                Text("4:3").tag(DesktopShape.landscape4x3)
                Text("21:9").tag(DesktopShape.ultrawide)
            }
            Section("Portrait") {
                Text("3:4").tag(DesktopShape.portrait3x4)
                Text("10:16").tag(DesktopShape.portrait10x16)
                Text("9:16").tag(DesktopShape.portrait9x16)
            }
            Section("Square") {
                Text("1:1").tag(DesktopShape.square)
            }
        }
        .pickerStyle(.navigationLink)
        .accessibilityIdentifier("settings.desktopShape")
    }
}
