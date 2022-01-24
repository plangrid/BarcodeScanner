//
//  AlloyScannerViewController.swift
//  BarcodeScanner-iOS
//
//  Created by Marco Emilio Vazquez Calva on 18/01/22.
//  Copyright © 2022 Hyper Interaktiv AS. All rights reserved.
//

import AVFoundation
import UIKit

class AlloyScannerViewController: UIViewController, CameraControllerProtocol {
  // MARK: - CameraControllerProtocol Properties
  var metadata: [AVMetadataObject.ObjectType] = [AVMetadataObject.ObjectType]()
  weak var delegate: CameraViewControllerDelegate?
  weak var multiScanDelegate: MultiScanProtocol?
  private let permissionService = VideoPermissionService()

  // MARK: - AVCapture Properties
  private var captureSession = AVCaptureSession()
  private var captureDevice: AVCaptureDevice?
  private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
  private var captureMetadataOutput = AVCaptureMetadataOutput()
  /// The current torch mode on the capture device.
  private var torchMode: TorchMode = .off {
    didSet {
      guard let captureDevice = captureDevice, captureDevice.hasFlash else { return }
      guard captureDevice.isTorchModeSupported(torchMode.captureTorchMode) else { return }

      do {
        try captureDevice.lockForConfiguration()
        captureDevice.torchMode = torchMode.captureTorchMode
        captureDevice.unlockForConfiguration()
      } catch {}
      flashButton.setImage(torchMode.image, for: .normal)
    }
  }
  private var isMultiScanEnabled: Bool = false

  // MARK: - UI Properties
  private let configuration: CameraViewConfigurationProtocol!
  private var focusView: UIView?
  private var borderShapeLayer: CAShapeLayer?

  private lazy var multiScanView: UIStackView = {
    let multiScanView = UIStackView()
    multiScanView.axis = .horizontal
    multiScanView.distribution = .equalCentering
    multiScanView.alignment = .center
    multiScanView.backgroundColor = .white
    multiScanView.isLayoutMarginsRelativeArrangement = true
    multiScanView.layoutMargins = UIEdgeInsets(top: 5, left: 16, bottom: 5, right: 16)
    multiScanView.translatesAutoresizingMaskIntoConstraints = false
    return multiScanView
  }()

  private lazy var flashButton: UIButton = {
    let flashButton = UIButton(type: .custom)
    flashButton.translatesAutoresizingMaskIntoConstraints = false
    flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
    return flashButton
  }()

  // MARK: - Actions
  @objc func flashButtonTapped() {
    torchMode = torchMode.next
  }

  @objc func multiScanChanged() {
    self.isMultiScanEnabled.toggle()
    self.multiScanDelegate?.multiScanChanged(enabled: self.isMultiScanEnabled)
  }

  @objc func appWillEnterForeground() {
    self.torchMode = .off
    self.startReadingAnimation()
  }

  // MARK: - Initializer
  init(configuration: CameraViewConfigurationProtocol) {
    self.configuration = configuration
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupCamera()
    self.torchMode = .off
    self.addMultiScanHeader()
    self.addFlashButton()
    self.addDescription()
    self.handleForegroundMode()
    self.setMultiScanMode()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.startReadingAnimation()
    self.setupRectOfInterest()
  }

  private func setupSessionOutput() {
    guard !isSimulatorRunning else {
      return
    }

    captureMetadataOutput = AVCaptureMetadataOutput()
    captureSession.addOutput(captureMetadataOutput)
    captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    captureMetadataOutput.metadataObjectTypes = metadata
    videoPreviewLayer?.session = captureSession

    view.setNeedsLayout()
  }

  private func setupBarcodeReader() {
    guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
      return
    }

    do {
      let input = try AVCaptureDeviceInput(device: captureDevice)
      self.captureDevice = captureDevice
      captureSession.addInput(input)

      captureMetadataOutput = AVCaptureMetadataOutput()
      captureSession.addOutput(captureMetadataOutput)

      captureMetadataOutput.setMetadataObjectsDelegate(self, queue: .main)
      captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]

      // Initialize preview layer
      videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
      videoPreviewLayer?.videoGravity = .resizeAspectFill
      videoPreviewLayer?.frame = view.layer.bounds
      view.layer.addSublayer(videoPreviewLayer!)

      captureSession.startRunning()

      // Initialize qr code frame to highlight qr code
      self.addFocusView()
    } catch {
      delegate?.cameraViewController(
        self,
        didReceiveError: error
      )
      return
    }
  }

  private func setupCamera() {
    permissionService.checkPersmission { [weak self] error in
      guard let strongSelf = self else {
        return
      }

      if error == nil {
        strongSelf.setupBarcodeReader()
        strongSelf.delegate?.cameraViewControllerDidSetupCaptureSession(strongSelf)
      } else {
        strongSelf.delegate?.cameraViewController(
          strongSelf,
          didReceiveError: AlloyError.cameraAccessDenied
        )
      }
    }
  }

  private func setupRectOfInterest() {
    typealias RectConstants = AlloyScannerConstants.RectOfInterest

    guard let videoPreview = self.videoPreviewLayer else { return }
    let width = view.frame.width * RectConstants.widthPercentage
    let height = view.frame.height * RectConstants.heightPercentage
    let centerX = view.center.x - (width / RectConstants.middle)
    let centerY = view.center.y - (height / RectConstants.middle)
    let rectOfInterest = videoPreview.metadataOutputRectConverted(
      fromLayerRect: CGRect(
        x: centerX,
        y: centerY,
        width: width,
        height: height)
    )
    captureMetadataOutput.rectOfInterest = rectOfInterest
  }

  func startCapturing() {
    self.captureSession.startRunning()
  }

  func stopCapturing() {
    self.captureSession.stopRunning()
  }

  private func handleForegroundMode() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  private func setMultiScanMode() {
    self.isMultiScanEnabled = configuration.isMultiScanEnabled
    self.multiScanDelegate?.multiScanChanged(enabled: configuration.isMultiScanEnabled)
  }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension AlloyScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
  public func metadataOutput(_ output: AVCaptureMetadataOutput,
                             didOutput metadataObjects: [AVMetadataObject],
                             from connection: AVCaptureConnection) {
    delegate?.cameraViewController(self, didOutput: metadataObjects)
  }
}

// MARK: - Overlay Bounding Box
extension AlloyScannerViewController {
  typealias BoundingBoxConstants = AlloyScannerConstants.BoundingBox

  func createOverlay() -> UIView {
    // Create the view and add the blur
    let overlayView = UIView(frame: view.frame)
    overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.4)

    // Frame
    let width = view.frame.width * BoundingBoxConstants.horizontalPadding
    let height = view.frame.height * BoundingBoxConstants.verticalPadding
    let centerX = view.center.x - (width / BoundingBoxConstants.middle)
    let centerY = view.center.y - (height / BoundingBoxConstants.middle)

    // Add rectangle that will be our rect of interest
    let path = CGMutablePath()
    path.addRoundedRect(
      in: CGRect(x: centerX,
                 y: centerY,
                 width: width,
                 height: height),
      cornerWidth: BoundingBoxConstants.cornerSize,
      cornerHeight: BoundingBoxConstants.cornerSize)
    path.closeSubpath()

    // Add border to our rectangle
    borderShapeLayer = CAShapeLayer()
    guard let borderShape = self.borderShapeLayer else {
      return UIView()
    }
    borderShape.path = path
    borderShape.lineWidth = BoundingBoxConstants.borderWidth
    borderShape.strokeColor = self.configuration.focusViewStrokeColor.cgColor
    overlayView.layer.addSublayer(borderShape)

    path.addRect(CGRect(origin: .zero, size: overlayView.frame.size))

    let maskLayer = CAShapeLayer()
    maskLayer.backgroundColor = UIColor.black.cgColor
    maskLayer.path = path
    maskLayer.fillRule = CAShapeLayerFillRule.evenOdd

    overlayView.layer.mask = maskLayer
    overlayView.clipsToBounds = true

    return overlayView
  }
}

// MARK: - Bounding box Animations
extension AlloyScannerViewController {
  typealias AnimationConstants = AlloyScannerConstants.ReadingAnimation

  private func startReadingAnimation() {
    borderShapeLayer?.removeAllAnimations()
    let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
    animation.fromValue = AnimationConstants.fromValue
    animation.toValue = AnimationConstants.toValue
    animation.duration = AnimationConstants.duration
    animation.repeatCount = .infinity
    animation.autoreverses = true
    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    borderShapeLayer?.add(animation, forKey: #keyPath(CALayer.opacity))

    view.layoutIfNeeded()
  }

  private func stopReadingAnimation() {
    borderShapeLayer?.removeAllAnimations()
  }

  private func stopAnimations() {
    borderShapeLayer?.removeAllAnimations()
  }
}

// MARK: - Layout
extension AlloyScannerViewController {
  typealias LayoutConstants = AlloyScannerConstants.LayoutConstants

  func addFocusView() {
    self.focusView = createOverlay()
    if let focusView = self.focusView {
      view.addSubview(focusView)
      self.view.bringSubviewToFront(focusView)
    }
  }

  private func addFlashButton() {
    self.view.addSubview(flashButton)

    NSLayoutConstraint.activate([
      flashButton.topAnchor.constraint(
        equalTo: self.multiScanView.bottomAnchor,
        constant: LayoutConstants.flashButtonTop
      ),
      flashButton.trailingAnchor.constraint(
        equalTo: self.view.trailingAnchor,
        constant: LayoutConstants.flashButtonLeading
      )
    ])
  }

  private func addMultiScanHeader() {
    let multiScanContainer = UIView()
    multiScanContainer.translatesAutoresizingMaskIntoConstraints = false

    // Text
    let multiScanLabel = UILabel()
    multiScanLabel.attributedText = configuration.multiScanTitle
    multiScanLabel.textColor = .black

    let multiScanSwitch = UISwitch()
    multiScanSwitch.addTarget(self, action: #selector(multiScanChanged), for: .valueChanged)
    multiScanSwitch.isOn = configuration.isMultiScanEnabled

    multiScanView.addArrangedSubview(multiScanLabel)
    multiScanView.addArrangedSubview(multiScanSwitch)

    self.view.addSubview(multiScanView)
    if #available(iOS 11.0, *) {
      NSLayoutConstraint.activate([
        multiScanView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
      ])
    } else {
      NSLayoutConstraint.activate([
        multiScanView.topAnchor.constraint(equalTo: view.topAnchor, constant: LayoutConstants.multiScanViewTop)
      ])
    }

    NSLayoutConstraint.activate([
      multiScanView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      multiScanView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      multiScanView.heightAnchor.constraint(equalToConstant: LayoutConstants.multiScanViewHeight)
    ])
  }

  private func addDescription() {
    let descriptionLabel = UILabel()
    descriptionLabel.attributedText = configuration.descriptionText
    descriptionLabel.textColor = .white
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

    guard let focusView = self.focusView else { return }
    self.view.addSubview(descriptionLabel)
    self.view.bringSubviewToFront(descriptionLabel)

    NSLayoutConstraint.activate([
      descriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      descriptionLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -(focusView.frame.height / LayoutConstants.viewHeightPercentage))
    ])
  }
}
