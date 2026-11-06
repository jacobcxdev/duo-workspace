import SwiftUI

final class KeyboardAccessoryContainer: UIInputView {
    let host: UIHostingController<KeyboardAccessoryView>

    init(content: KeyboardAccessoryView) {
        host = UIHostingController(rootView: content)
        host.safeAreaRegions = []
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: KeyboardAccessoryMetrics.minimumHeight), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        autoresizingMask = [.flexibleWidth]
        backgroundColor = .secondarySystemBackground
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: KeyboardAccessoryContainer, _) in
            view.invalidateIntrinsicContentSize()
        }
    }

    required init?(coder: NSCoder) { fatalError("Created by the remote keyboard field") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric,
               height: KeyboardAccessoryMetrics.height(for: traitCollection))
    }
}
