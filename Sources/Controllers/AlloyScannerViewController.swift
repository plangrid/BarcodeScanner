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
  private var dashedView: DashedView?

  // MARK: - UI Properties
  private let configuration: CameraViewConfigurationProtocol
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

  private lazy var findItemButton: UIButton = {
    let button = UIButton(type: .custom)
    button.frame = .zero
    button.setImage(UIImage(named: "findItem"), for: .normal)
    button.setTitle("Find Item", for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 20)
    button.backgroundColor = .blue
    button.titleLabel?.textColor = .white
    button.layer.cornerRadius = 8
    //button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(willTappedFindItem), for: .touchUpInside)
    return button
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

  @objc func willTappedFindItem() {
    //self.delegate?.cameraViewController(self, didOutput: <#T##[AVMetadataObject]#>)
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
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.startReadingAnimation()
    self.setupRectOfInterest()
  }

  private func setupView() {
    self.torchMode = .off
    self.addMultiScanHeaderIfNeeded()
    self.addFlashButtonIfNeeded()
    self.addDescription()
    self.handleForegroundMode()
    self.startReadingAnimation()
    self.drawFindButton()
    dashedView = DashedView()

    if let dashedView = dashedView {
      self.view.addSubview(dashedView)
      self.view.bringSubviewToFront(dashedView)
    }
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
    guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }

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
        strongSelf.setupView()
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
//    typealias RectConstants = AlloyScannerConstants.RectOfInterest
//
//    guard let videoPreview = self.videoPreviewLayer else { return }
//    let width = view.frame.width * RectConstants.widthPercentage
//    let height = view.frame.height * RectConstants.heightPercentage
//    let centerX = view.center.x - (width / RectConstants.middle)
//    let centerY = view.center.y - (height / RectConstants.middle)
//    let rectOfInterest = videoPreview.metadataOutputRectConverted(
//      fromLayerRect: CGRect(
//        x: centerX,
//        y: centerY,
//        width: width,
//        height: height)
//    )
//    captureMetadataOutput.rectOfInterest = rectOfInterest
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
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension AlloyScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
  public func metadataOutput(_ output: AVCaptureMetadataOutput,
                             didOutput metadataObjects: [AVMetadataObject],
                             from connection: AVCaptureConnection) {
    if metadataObjects.isEmpty {
      dashedView?.frame = .zero
      findItemButton.isHidden = true
      return
    }

    guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
      return
    }

    guard let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObject) else { return }
    drawOutlinedView(onBounds: barCodeObject.bounds)
    //delegate?.cameraViewController(self, didOutput: metadataObjects)
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

  private func addFlashButtonIfNeeded() {
    guard configuration.isTorchModeAvailable else { return }
    self.view.addSubview(flashButton)

    if #available(iOS 11.0, *), !configuration.isMultiScanningAvailable {
      NSLayoutConstraint.activate([
        flashButton.topAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.topAnchor,
          constant: LayoutConstants.flashButtonTop
        )
      ])
    } else {
      NSLayoutConstraint.activate([
        flashButton.topAnchor.constraint(
          equalTo: multiScanView.bottomAnchor,
          constant: LayoutConstants.flashButtonTop
        )
      ])
    }

    NSLayoutConstraint.activate([
      flashButton.trailingAnchor.constraint(
        equalTo: self.view.trailingAnchor,
        constant: LayoutConstants.flashButtonLeading
      )
    ])
  }

  private func addMultiScanHeaderIfNeeded() {
    guard configuration.isMultiScanningAvailable else { return }
    let multiScanContainer = UIView()
    multiScanContainer.translatesAutoresizingMaskIntoConstraints = false

    // Text
    let multiScanLabel = UILabel()
    multiScanLabel.attributedText = configuration.multiScanTitle
    multiScanLabel.textColor = .black

    let multiScanSwitch = UISwitch()
    multiScanSwitch.addTarget(self, action: #selector(multiScanChanged), for: .valueChanged)

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
      descriptionLabel.centerYAnchor.constraint(
        equalTo: view.centerYAnchor,
        constant: -(focusView.frame.height / LayoutConstants.viewHeightPercentage)
      )
    ])
  }

  private func drawOutlinedView(onBounds bounds: CGRect) {
    if isInsideFocusView(bounds: bounds) {
      dashedView?.drawAsGreen()
      dashedView?.frame = bounds
      findItemButton.isHidden = false
    } else {
      dashedView?.drawAsYellow()
      dashedView?.frame = bounds
       findItemButton.isHidden = true
    }
  }

  private func drawFindButton() {
    guard let focusView = self.focusView else { return }
    //findItemButton.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(findItemButton)
    self.view.bringSubviewToFront(findItemButton)

//     NSLayoutConstraint.activate([
//      findItemButton.topAnchor.constraint(equalTo: focusView.bottomAnchor, constant: 50),
//      findItemButton.widthAnchor.constraint(equalTo: focusView.widthAnchor),
//      findItemButton.centerXAnchor.constraint(equalTo: focusView.centerXAnchor),
//      findItemButton.heightAnchor.constraint(equalToConstant: 32)
//     ])

    findItemButton.frame = CGRect(x: view.center.x - 100, y: 150, width: 200, height: 30)
    findItemButton.isHidden = true
    //view.layoutIfNeeded()
  }

  private func isInsideFocusView(bounds: CGRect) -> Bool {
    typealias RectConstants = AlloyScannerConstants.RectOfInterest

    let width = view.frame.width * 0.65//RectConstants.widthPercentage
    let height = view.frame.height * 0.30//RectConstants.heightPercentage
    let centerX = view.center.x - (width / RectConstants.middle)
    let centerY = view.center.y - (height / RectConstants.middle)

    let rectConverted = CGRect(x: centerX, y: centerY, width: width, height: height)
    return rectConverted.contains(bounds)
  }
}

protocol DashedViewConfigurationProtocol {
  var cornerRadius: CGFloat { get }
  var dashWidth: CGFloat { get }
  var dashColor: UIColor { get }
  var dashLenght: CGFloat { get }
  var dashesSpace: CGFloat { get }
}

struct DashedViewConfiguration: DashedViewConfigurationProtocol {
  var cornerRadius: CGFloat = 5
  var dashWidth: CGFloat = 3
  var dashColor: UIColor = UIColor.yellow
  var dashLenght: CGFloat = 3
  var dashesSpace: CGFloat = 4
}

class DashedView: UIView {

  let shapeLayer = CAShapeLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  func commonInit() {
    layer.addSublayer(shapeLayer)
  }

  func drawAsGreen() {
    shapeLayer.fillColor = UIColor.clear.cgColor
    shapeLayer.strokeColor = UIColor.green.cgColor
    shapeLayer.lineWidth = 3
    shapeLayer.lineJoin = .round
    self.setNeedsDisplay()
  }

  func drawAsYellow() {
    let color = UIColor.yellow.cgColor
    shapeLayer.fillColor = UIColor.clear.cgColor
    shapeLayer.strokeColor = color
    shapeLayer.lineWidth = 2
    shapeLayer.lineJoin = .round
    shapeLayer.lineDashPattern = [6,3]
    self.setNeedsDisplay()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    shapeLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: 4).cgPath
  }
}
