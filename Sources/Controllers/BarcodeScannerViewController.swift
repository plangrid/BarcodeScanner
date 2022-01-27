import UIKit
import AVFoundation

/**
 Barcode scanner controller with 4 sates:
 - Scanning mode
 - Processing animation
 - Unauthorized mode
 - Not found error message
 */
open class BarcodeScannerViewController: UIViewController {

  private static let footerHeight: CGFloat = 91
  private static let headerHeight: CGFloat = 173
  private static let headerRightPadding: CGFloat = -50

  // MARK: - Public properties

  /// Delegate to handle the captured code.
  public weak var codeDelegate: BarcodeScannerCodeDelegate?
  /// Delegate to report errors.
  public weak var errorDelegate: BarcodeScannerErrorDelegate?
  /// Delegate to dismiss barcode scanner when the close button has been pressed.
  public weak var dismissalDelegate: BarcodeScannerDismissalDelegate?

  /// Stop scanning when other object besides a MachineReadableCodeObject is detected
  public var stopCaptureWhenDetectingOtherObject = true

  /// `AVCaptureMetadataOutput` metadata object types.
  public var metadata = AVMetadataObject.ObjectType.barcodeScannerMetadata {
    didSet {
      cameraViewController?.metadata = metadata
    }
  }

  // MARK: - Private properties

  /// Flag to lock session from capturing.
  private var locked = false
  /// Flag to check if layout constraints has been activated.
  private var constraintsActivated = false
  /// Flag to check if view controller is currently on screen
  private var isVisible = false

  // MARK: - MultiScan Properties
  var isMultiScanEnabled: Bool = true

  // MARK: - UI

  public private(set) var footerVC: FooterViewController = FooterViewController()
  private(set) var cameraViewController: CameraControllerProtocol? = CameraViewController()
  public private(set) var cameraHeaderVC: CameraHeaderViewController = CameraHeaderViewController()

  // Constraints that are activated when the view is used as a footer.
  private lazy var collapsedConstraints: [NSLayoutConstraint] = self.makeCollapsedConstraints()

  private var footerView: UIView {
    return footerVC.view
  }

  private var headerView: UIView {
    return cameraHeaderVC.view
  }

  /// The current controller's status mode.
  private var status: Status = Status(state: .scanning) {
    didSet {
      changeStatus(from: oldValue, to: status)
    }
  }

  public func setCameraController(type: CameraViewType) {
    self.cameraViewController = type.controller
  }

  // MARK: - View lifecycle

  open override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.black

    self.setupCameraController()
    self.addHeaderIfNeeded()
    self.addFooterIfNeeded()
    self.setupCameraConstraints()

    collapsedConstraints.activate()
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    setupCameraConstraints()
    isVisible = true
  }

  open override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    isVisible = false
  }

  // MARK: - Camera capture session

  public func stopCameraCapture() {
    self.cameraViewController?.stopCapturing()
  }

  public func resumeCameraCapture() {
    self.cameraViewController?.startCapturing()
  }

  // MARK: - State handling

  /**
   Shows error message and goes back to the scanning mode.
   - Parameter errorMessage: Error message that overrides the message from the config.
   */
  public func resetWithError(message: String? = nil) {
    status = Status(state: .notFound, text: message)
  }

  /**
   Resets the controller to the scanning mode.
   - Parameter animated: Flag to show scanner with or without animation.
   */
  public func reset(animated: Bool = true) {
    status = Status(state: .scanning, animated: animated)
  }

  private func changeStatus(from oldValue: Status, to newValue: Status) {
    guard newValue.state != .notFound else {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
        self.status = Status(state: .scanning)
      }
      return
    }

    let delayReset = oldValue.state == .processing || oldValue.state == .notFound

    if !delayReset {
      resetState()
    }
  }

  /// Resets the current state.
  private func resetState() {
    locked = status.state == .processing
    if status.state == .scanning {
      cameraViewController?.startCapturing()
    } else {
      cameraViewController?.stopCapturing()
    }
  }

  private func setupCameraController() {
    guard let cameraViewController = cameraViewController as? UIViewController else { return }
    self.cameraViewController?.metadata = metadata
    self.cameraViewController?.delegate = self
    self.cameraViewController?.multiScanDelegate = self
    add(childViewController: cameraViewController)
  }

  private func addHeaderIfNeeded() {
    add(childViewController: cameraHeaderVC)
    headerView.translatesAutoresizingMaskIntoConstraints = false
    view.bringSubviewToFront(headerView)
  }

  private func addFooterIfNeeded() {
    add(childViewController: footerVC)
    footerView.translatesAutoresizingMaskIntoConstraints = false
    view.bringSubviewToFront(footerView)
  }

  // MARK: - Animations

  /**
   Simulates flash animation.
   - Parameter processing: Flag to set the current state to `.processing`.
   */
  private func animateFlash() {
    let flashView = UIView(frame: view.bounds)
    flashView.backgroundColor = UIColor.white
    flashView.alpha = 1

    view.addSubview(flashView)
    view.bringSubviewToFront(flashView)

    UIView.animate(
      withDuration: 0.2,
      animations: ({
        flashView.alpha = 0.0
      }),
      completion: ({ _ in
        flashView.removeFromSuperview()
      }))
  }
}

// MARK: - Layout

private extension BarcodeScannerViewController {
  private func setupCameraConstraints() {
    guard !constraintsActivated else {
      return
    }

    constraintsActivated = true

    guard let cameraView = (cameraViewController as? UIViewController)?.view else { return }

    NSLayoutConstraint.activate(
      cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      cameraView.bottomAnchor.constraint(equalTo: footerView.bottomAnchor),
      cameraView.topAnchor.constraint(equalTo: headerView.topAnchor)
    )
  }

  private func makeCollapsedConstraints() -> [NSLayoutConstraint] {
    return [
      footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      footerView.heightAnchor.constraint(
        equalToConstant: BarcodeScannerViewController.footerHeight
      ),

      headerView.topAnchor.constraint(equalTo: view.topAnchor),
      headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: BarcodeScannerViewController.headerRightPadding),
      headerView.heightAnchor.constraint(
        equalToConstant: BarcodeScannerViewController.headerHeight
      )
    ]
  }
}

// MARK: - CameraViewControllerDelegate

extension BarcodeScannerViewController: CameraViewControllerDelegate {
  func cameraViewControllerDidSetupCaptureSession(_ controller: CameraControllerProtocol) {
    status = Status(state: .scanning)
  }

  func cameraViewControllerDidFailToSetupCaptureSession(_ controller: CameraControllerProtocol) {
    status = Status(state: .unauthorized)
  }

  func cameraViewController(_ controller: CameraControllerProtocol, didReceiveError error: Error) {
    errorDelegate?.scanner(self, didReceiveError: .unexpected(error))
  }

  func cameraViewControllerDidTapSettingsButton(_ controller: CameraControllerProtocol) {
    DispatchQueue.main.async {
      if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.openURL(settingsURL)
      }
    }
  }

  func cameraViewController(_ controller: CameraControllerProtocol,
                            didOutput metadataObjects: [AVMetadataObject]) {
    guard !locked && isVisible else { return }
    guard !metadataObjects.isEmpty else { return }
    guard let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
      if self.stopCaptureWhenDetectingOtherObject { controller.stopCapturing() }
      errorDelegate?.scanner(self, didReceiveError: .nonMachineReadableCodeDetected)
      return
    }

    if !isMultiScanEnabled {
      controller.stopCapturing()
    }

    guard var code = metadataObj.stringValue, metadata.contains(metadataObj.type) else {
      errorDelegate?.scanner(self, didReceiveError: .unsupported)
      if !isMultiScanEnabled { controller.stopCapturing() }
      return
    }

    var rawType = metadataObj.type.rawValue

    // UPC-A is an EAN-13 barcode with a zero prefix.
    // See: https://stackoverflow.com/questions/22767584/ios7-barcode-scanner-api-adds-a-zero-to-upca-barcode-format
    if metadataObj.type == AVMetadataObject.ObjectType.ean13 && code.hasPrefix("0") {
      code = String(code.dropFirst())
      rawType = AVMetadataObject.ObjectType.upca.rawValue
    }

    codeDelegate?.scanner(self, didCaptureCode: code, type: rawType)
    animateFlash()
  }
}

// MARK: - MultiScanProtocol
extension BarcodeScannerViewController: MultiScanProtocol {
  func multiScanChanged(enabled: Bool) {
    self.isMultiScanEnabled = enabled
  }
}
