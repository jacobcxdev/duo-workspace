import SwiftUI
import DuoCore

struct PointerModePicker: View {
    @Bindable var settings: AppSettings

    var body: some View {
        AdaptiveFormPicker("Pointer mode", selection: $settings.pointerMode) {
            ForEach(PointerMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .accessibilityIdentifier("input.pointerMode")
    }
}
