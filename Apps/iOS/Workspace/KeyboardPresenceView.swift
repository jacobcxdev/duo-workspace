import UIKit

final class KeyboardPresenceView: UIView {
    var changed: (KeyboardPresentation) -> Void
    private let boundary = UIView()
    private var lastPresentation: KeyboardPresentation?
    #if DEBUG
    private var lastDiagnostic = ""
    #endif

    init(changed: @escaping (KeyboardPresentation) -> Void) {
        self.changed = changed
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        keyboardLayoutGuide.usesBottomSafeArea = false
        keyboardLayoutGuide.followsUndockedKeyboard = true
        boundary.translatesAutoresizingMaskIntoConstraints = false
        addSubview(boundary)
        NSLayoutConstraint.activate([
            boundary.leadingAnchor.constraint(equalTo: leadingAnchor),
            boundary.topAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
            boundary.widthAnchor.constraint(equalToConstant: 0),
            boundary.heightAnchor.constraint(equalToConstant: 0)
        ])
    }

    required init?(coder: NSCoder) { fatalError("Created by the session") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let frame = keyboardLayoutGuide.layoutFrame.intersection(bounds)
        let occupiedHeight = frame.isNull ? 0 : frame.height
        let accessoryHeight = KeyboardAccessoryMetrics.height(for: traitCollection)
        let presentation = KeyboardPresentation.measured(occupiedHeight: occupiedHeight, accessoryHeight: accessoryHeight)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--layout-diagnostics") {
            let value = "bounds=\(bounds) keyboard=\(keyboardLayoutGuide.layoutFrame) occupied=\(occupiedHeight) accessory=\(accessoryHeight) presentation=\(presentation)"
            if value != lastDiagnostic { try? FileHandle.standardOutput.write(contentsOf: Data("DuoKeyboard \(value)\n".utf8)); lastDiagnostic = value }
        }
        #endif
        guard presentation != lastPresentation else { return }
        lastPresentation = presentation
        DispatchQueue.main.async { [weak self] in
            guard let self, lastPresentation == presentation else { return }
            changed(presentation)
        }
    }
}
