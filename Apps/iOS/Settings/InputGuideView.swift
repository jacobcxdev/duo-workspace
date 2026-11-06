import SwiftUI

struct InputGuideView: View {
    let settings: AppSettings

    var body: some View {
        List {
            if settings.pointerMode == .nativeTouch {
                Section("Native touch") {
                    Text("Touch the Mac image directly with up to five fingers. macOS handles taps, dragging and multi-finger gestures.")
                    Text("Mac controls can expand when touched. Gesture behavior follows the Mac and the app you're using.")
                    Text("The lower tabletop trackpad keeps its pointer and scroll controls.")
                }
            } else {
              Section("Point & click") {
                LabeledContent("Move pointer", value: settings.pointerMode == .direct ? "Touch the Mac image" : "Slide one finger")
                LabeledContent("Click", value: "Tap once")
                if settings.pointerMode == .direct {
                    LabeledContent("Double-tap") { Text(settings.touchDoubleTapAction.title) }
                } else {
                    LabeledContent("Double-click", value: "Tap twice")
                }
                LabeledContent("Right-click", value: "Tap with two fingers")
                LabeledContent("Drag", value: "Hold, then move")
                LabeledContent("Scroll", value: "Slide two fingers")
              }
            }
            Section("Keyboard") {
                Text("Open Keyboard to type. Modifiers apply to the next key, click or scroll. Drag holds them until Drop.")
                Text("Open F1–F12 in Mac keys or the keyboard row. Fn-Delete deletes forwards; Fn with an arrow sends Home, End, Page Up or Page Down. Fn releases after the next action.")
                Text("Folding, leaving the app and disconnecting release held keys and buttons.")
                Text("Open Mac keys in Session. Copy and Paste use the Mac's clipboard.")
            }
            Section("When you fold") {
                Text("In tabletop, controls sit below the fold. Hiding the keyboard restores the trackpad when space allows. A vertical fold uses one canvas.")
                Text("Swipe inward at either side mark to show controls. Accessibility actions also work.")
            }
        }
        .navigationTitle("Keyboard & gestures")
        .navigationBarTitleDisplayMode(.inline)
    }
}
