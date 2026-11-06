import SwiftUI

struct KeyboardAvoidingRegion<Content: View>: UIViewControllerRepresentable {
    @ContentBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.locale) private var locale
    @Environment(\.isEnabled) private var isEnabled

    func makeUIViewController(context: Context) -> KeyboardRegionController<RegionContent<Content>> {
        KeyboardRegionController(content: hostedContent)
    }

    func updateUIViewController(_ controller: KeyboardRegionController<RegionContent<Content>>, context: Context) {
        controller.host.rootView = hostedContent
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: KeyboardRegionController<RegionContent<Content>>, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height, width.isFinite, height.isFinite else { return nil }
        return CGSize(width: width, height: height)
    }

    private var hostedContent: RegionContent<Content> {
        RegionContent(content: content, values: RegionEnvironment(colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize, layoutDirection: layoutDirection, locale: locale, isEnabled: isEnabled))
    }
}
