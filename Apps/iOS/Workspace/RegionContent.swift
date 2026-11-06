import SwiftUI

struct RegionContent<Content: View>: View {
    let content: Content
    let values: RegionEnvironment

    var body: some View {
        content
            .environment(\.colorScheme, values.colorScheme)
            .environment(\.dynamicTypeSize, values.dynamicTypeSize)
            .environment(\.layoutDirection, values.layoutDirection)
            .environment(\.locale, values.locale)
            .environment(\.isEnabled, values.isEnabled)
            .tint(.accentColor)
    }
}
