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
  private var focusView: UIView?
  private var borderShapeLayer: CAShapeLayer?
  private var headerView: UIStackView?
  private var multiScanView: UIView?

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
    self.multiScanDelegate?.multiScanChanged(enabled: isMultiScanEnabled)
  }

  // MARK: - Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupCamera()
    self.torchMode = .off
    self.addFlashButton()
    self.addMultiScanHeader()
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
    guard let videoPreview = self.videoPreviewLayer else { return }
    let width = view.frame.width * 0.80
    let height = view.frame.height * 0.20
    let centerX = view.center.x - (width / 2)
    let centerY = view.center.y - (height / 2)
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
  typealias Constants = BarCodeConstants.BoundingBox

  func createOverlay() -> UIView {
    // Create the view and add the blur
    let overlayView = UIView(frame: view.frame)
    overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.4)

    // Frame
    let width = view.frame.width * Constants.horizontalPadding
    let height = view.frame.height * Constants.verticalPadding
    let centerX = view.center.x - (width / Constants.middle)
    let centerY = view.center.y - (height / Constants.middle)

    // Add rectangle that will be our rect of interest
    let path = CGMutablePath()
    path.addRoundedRect(
      in: CGRect(x: centerX,
                 y: centerY,
                 width: width,
                 height: height),
      cornerWidth: Constants.cornerSize,
      cornerHeight: Constants.cornerSize)
    path.closeSubpath()

    // Add border to our rectangle
    borderShapeLayer = CAShapeLayer()
    guard let borderShape = self.borderShapeLayer else {
      return UIView()
    }
    borderShape.path = path
    borderShape.lineWidth = Constants.borderWidth
    borderShape.strokeColor = UIColor.white.cgColor
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
  typealias AnimationConstants = BarCodeConstants.ReadingAnimation

  private func startReadingAnimation() {
    let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
    animation.fromValue = AnimationConstants.fromValue
    animation.toValue = AnimationConstants.toValue
    animation.duration = AnimationConstants.duration
    animation.repeatCount = .infinity
    animation.autoreverses = true
    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    borderShapeLayer?.add(animation, forKey: #keyPath(CALayer.opacity))
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
  func addFocusView() {
    self.focusView = createOverlay()
    if let focusView = self.focusView {
      view.addSubview(focusView)
      self.view.bringSubviewToFront(focusView)
    }
  }

  private func addFlashButton() {
    self.view.addSubview(flashButton)

    if #available(iOS 11.0, *) {
      NSLayoutConstraint.activate([
        flashButton.topAnchor.constraint(
          equalTo: self.view.safeAreaLayoutGuide.topAnchor,
          constant: 10
        ),
        flashButton.trailingAnchor.constraint(
          equalTo: self.view.trailingAnchor,
          constant: -16
        )
      ])
    } else {
      // Fallback on earlier versions
    }
  }

  private func addMultiScanHeader() {
    let multiScanContainer = UIView()
    multiScanContainer.translatesAutoresizingMaskIntoConstraints = false

    // Text
    let multiScanLabel = UILabel()
    multiScanLabel.text = "Scan multiple assets"
    multiScanLabel.textColor = .black

    let multiScanSwitch = UISwitch()
    multiScanSwitch.addTarget(self, action: #selector(multiScanChanged), for: .valueChanged)

    let stackContainer = UIStackView(arrangedSubviews: [
      multiScanLabel,
      multiScanSwitch
    ])
    stackContainer.axis = .horizontal
    stackContainer.distribution = .equalCentering
    stackContainer.alignment = .center
    stackContainer.backgroundColor = .white
    stackContainer.isLayoutMarginsRelativeArrangement = true
    stackContainer.layoutMargins = UIEdgeInsets(top: 5, left: 16, bottom: 5, right: 16)
    stackContainer.translatesAutoresizingMaskIntoConstraints = false

    self.view.addSubview(stackContainer)
    if #available(iOS 11.0, *) {
      NSLayoutConstraint.activate([
        stackContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        stackContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        stackContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        stackContainer.heightAnchor.constraint(equalToConstant: 57)
      ])
    } else {
      // Fallback on earlier versions
    }
  }
}
