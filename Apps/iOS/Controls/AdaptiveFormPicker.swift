import SwiftUI

struct AdaptiveFormPicker<Selection: Hashable, Content: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Selection
    let content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ title: LocalizedStringKey, selection: Binding<Selection>, @ViewBuilder content: () -> Content) {
        self.title = title
        _selection = selection
        self.content = content()
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker(title, selection: $selection) { content }
                .pickerStyle(.inline)
        } else {
            Picker(title, selection: $selection) { content }
                .pickerStyle(.menu)
        }
    }
}
