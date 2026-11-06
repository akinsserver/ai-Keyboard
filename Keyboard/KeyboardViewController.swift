import UIKit
import SwiftUI
import ReplyKit

/// The custom keyboard extension.
///
/// Hosts the SwiftUI keyboard view. All AI work (OCR and network) runs
/// off the main thread inside the view model; this controller only owns
/// the hosting controller and passes through the text document proxy.
///
/// The keyboard MUST still work as a plain QWERTY keyboard when
/// Allow Full Access is off (App Store Review Guideline 4.4.1). In that
/// case the view model shows an explanation and disables the AI buttons,
/// but typing, delete, space and return keep working.
final class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardView>?
    private let viewModel = KeyboardViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.controller = self
        let keyboardView = KeyboardView(viewModel: viewModel)
        let hosting = UIHostingController(rootView: keyboardView)
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // `hasFullAccess` is only meaningful inside the extension.
        viewModel.hasFullAccess = hasFullAccess
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.hasFullAccess = hasFullAccess
    }
}
