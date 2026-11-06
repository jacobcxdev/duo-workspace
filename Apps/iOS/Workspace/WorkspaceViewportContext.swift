import Foundation

struct WorkspaceViewportContext: Equatable {
    enum Layout: Equatable { case canvas, tabletop }
    let rootSize: CGSize
    let layout: Layout
    let keyboardMode: Bool
    let keyboardPresentation: KeyboardPresentation
}
