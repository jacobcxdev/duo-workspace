import SwiftUI

final class KeyboardRegionController<Content: View>: UIViewController {
    let host: UIHostingController<Content>
    #if DEBUG
    private var lastDiagnostic = ""
    #endif

    init(content: Content) {
        host = UIHostingController(rootView: content)
        host.safeAreaRegions = [.container]
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Not used by the native layout") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.keyboardLayoutGuide.usesBottomSafeArea = false
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        host.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--layout-diagnostics") {
            let value = "region=\(view.frame) bounds=\(view.bounds) content=\(host.view.frame) keyboard=\(view.keyboardLayoutGuide.layoutFrame)"
            if value != lastDiagnostic { try? FileHandle.standardOutput.write(contentsOf: Data("DuoLayout \(value)\n".utf8)); lastDiagnostic = value }
        }
        #endif
    }
}
