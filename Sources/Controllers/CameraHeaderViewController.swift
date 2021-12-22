//
//  CameraHeaderView.swift
//  BarcodeScanner-iOS
//
//  Created by Ido Zaltzberg on 8/21/19.
//  Copyright © 2019 Hyper Interaktiv AS. All rights reserved.
//

import UIKit

public final class CameraHeaderViewController: UIViewController {
    let imageSize: CGFloat = 59
    let stackViewOffset: CGFloat = 17
    let stackViewSpacing: CGFloat = 13
    let titleWidth: CGFloat = 119
    let titleHeight: CGFloat = 25
    let titleOffset: CGFloat = 42

    private var titleLabel: UILabel!
    private var barcodeImageView: UIImageView!
    private var qrImageView: UIImageView!
    private var barcodeLabel: UILabel!
    private var qrLabel: UILabel!
    private var barcodeStack: UIStackView!
    private var qrStack: UIStackView!

    // MARK: - Viewmodel
    private let viewModel: CameraHeaderViewProtocol

    // MARK: - Initializer
    init(viewModel: CameraHeaderViewProtocol = DefaultCameraHeaderViewModel()) {
      self.viewModel = viewModel
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        titleLabel = makeLabel(text: viewModel.title)
        barcodeLabel = makeLabel(text: viewModel.barCodeSubtitle)
        qrLabel = makeLabel(text: viewModel.qrSubtitle)
        barcodeImageView = makeImageView(image: viewModel.barcodeImage)
        qrImageView = makeImageView(image: viewModel.qrImage)
        qrStack = makeStackView(arrangedSubviews: [qrImageView, qrLabel])
        barcodeStack = makeStackView(arrangedSubviews: [barcodeImageView, barcodeLabel])
        view.addSubviews(titleLabel, barcodeStack, qrStack)
        applyConstraints()
    }

    private func makeLabel(text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = .white
        label.font = UIFont(name: "ArtifaktElement-Regular", size: 18)
        return label
    }

    private func makeImageView(image: UIImage?) -> UIImageView {
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .white
        return imageView
    }

    private func makeStackView(arrangedSubviews: [UIView]) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: arrangedSubviews)
        stackView.distribution = .equalSpacing
        stackView.spacing = stackViewSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }

    private func applyConstraints() {
        applyTitleLabelConstraints()
        applyStackViewsConstraints()
        applyImageViewConstraints(for: barcodeImageView)
        applyImageViewConstraints(for: qrImageView)
        applySubLabelConstraints()
    }

    private func applyTitleLabelConstraints() {
        titleLabel.widthAnchor.constraint(equalToConstant: titleWidth).isActive = true
        titleLabel.heightAnchor.constraint(equalToConstant: titleHeight).isActive = true
        titleLabel.centerXAnchor.constraint(equalTo: barcodeStack.centerXAnchor).isActive = true
        titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: titleOffset).isActive = true
    }

    private func applyStackViewsConstraints() {
        barcodeStack.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        barcodeStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor,
                                          constant: stackViewOffset).isActive = true
        qrStack.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        qrStack.topAnchor.constraint(equalTo: barcodeStack.bottomAnchor,
                                     constant: stackViewOffset).isActive = true
    }

    private func applyImageViewConstraints(for imageView: UIImageView) {
        imageView.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
    }

    private func applySubLabelConstraints() {
        barcodeLabel.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
        qrLabel.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
    }
}
