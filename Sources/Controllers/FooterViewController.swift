import UIKit

public final class FooterViewController: UIViewController {
    private var cancelButton: UIButton!

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        cancelButton = makeCancelButton()
        view.addSubview(cancelButton)
        applyConstraints()
    }
}

private extension FooterViewController {
    func makeCancelButton() -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(localizedString("BUTTON_CLOSE"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "ArtifaktElement-Regular", size: 18)
        button.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        return button
    }

    func applyConstraints() {
        cancelButton.widthAnchor.constraint(equalToConstant: 56).isActive = true
        cancelButton.heightAnchor.constraint(equalToConstant: 25).isActive = true
        cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        cancelButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }

    @objc func cancel() {
        if let parent = self.parent as? BarcodeScannerViewController {
            parent.dismissalDelegate?.scannerDidDismiss(parent)
        }

    }
}
