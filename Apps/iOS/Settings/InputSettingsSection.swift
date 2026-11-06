import SwiftUI

struct InputSettingsSection: View {
    @Bindable var settings: AppSettings
    var nativeTouch: SessionNativeTouch?
    var retryNativeTouch: (() -> Void)?

    var body: some View {
        Section {
            PointerModePicker(settings: settings)
            if settings.pointerMode == .nativeTouch {
                NativeTouchInfo(session: nativeTouch, retry: retryNativeTouch)
            } else if settings.pointerMode == .direct {
                AdaptiveFormPicker("Double-tap", selection: $settings.touchDoubleTapAction) {
                    ForEach(TouchDoubleTapAction.allCases, id: \.self) { action in
                        Text(action.title).tag(action)
                    }
                }
                .accessibilityIdentifier("input.doubleTap")
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Trackpad speed")
                    Spacer()
                    Text(settings.pointerSpeed, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $settings.pointerSpeed, in: 0.5...2, step: 0.1) { Text("Trackpad speed") }
            }
            Toggle("Natural scrolling", isOn: $settings.naturalScrolling)
            Toggle("Show trackpad hints", isOn: $settings.showHints)
        } header: { Text("Input") }
        footer: {
            if settings.pointerMode == .nativeTouch {
                Text("Trackpad speed and scrolling settings apply to the lower tabletop trackpad. Your Mac handles gestures on the desktop.")
            } else if settings.pointerMode == .direct {
                Text("Tap the Mac image to click there. Hold to drag. Scroll with two fingers. The tabletop trackpad stays relative.")
            } else {
                Text("Slide one finger to move the pointer. Tap to click. Hold to drag. Scroll with two fingers.")
            }
        }
    }
}
