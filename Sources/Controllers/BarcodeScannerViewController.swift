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
  private static let footerHeight: CGFloat = 75
  public var hideFooterView = false

  // MARK: - Public properties

  /// Delegate to handle the captured code.
  public weak var codeDelegate: BarcodeScannerCodeDelegate?
  /// Delegate to report errors.
  public weak var errorDelegate: BarcodeScannerErrorDelegate?
  /// Delegate to dismiss barcode scanner when the close button has been pressed.
  public weak var dismissalDelegate: BarcodeScannerDismissalDelegate?

  /// When the flag is set to `true` controller returns a captured code
  /// and waits for the next reset action.
  public var isOneTimeSearch = true

    /// When the flag is set to `true` the screen is flashed on barcode scan.
      /// Defaults to true.
  public var shouldSimulateFlash = true

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

  // MARK: - UI
  public private(set) lazy var footerVC: FooterViewController? = .init()
  public private(set) var cameraViewController: CameraControllerProtocol? = AlloyScannerViewController()
  public private(set) lazy var cameraHeaderVC: CameraHeaderViewController? = .init()

  // Constraints that are activated when the view is used as a footer.
  private lazy var collapsedConstraints: [NSLayoutConstraint] = self.makeCollapsedConstraints()
  // Constraints that are activated when the view is used for loading animation and error messages.
  private lazy var expandedConstraints: [NSLayoutConstraint] = self.makeExpandedConstraints()

  private var footerView: UIView {
    return footerVC?.view ?? UIView()
  }

  private var headerView: UIView {
    return cameraHeaderVC?.view ?? UIView()
  }
  /// The current controller's status mode.
  private var status: Status = Status(state: .scanning) {
    didSet {
      changeStatus(from: oldValue, to: status)
    }
  }

  // MARK: - Initializer
  public init(
    footerController: FooterViewController? = FooterViewController(),
    cameraController: CameraViewType? = .normal,
    headerController: CameraHeaderViewController? = CameraHeaderViewController()
  ) {
    super.init(nibName: nil, bundle: nil)
    self.footerVC = footerController
    self.cameraViewController = cameraController?.controller
    self.cameraHeaderVC = headerController
  }

  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View lifecycle
  open override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.black

    self.setupCameraController()
    self.addHeaderIfNeeded()
    self.addFooterIfNeeded()
    self.setupCameraConstraints()

    guard footerVC != nil && cameraHeaderVC != nil else { return }
    collapsedConstraints.activate()
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    //setupCameraConstraints()
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
      messageViewController.status = newValue
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
        self.status = Status(state: .scanning)
      }
      return
    }

    let animatedTransition = newValue.state == .processing
      || oldValue.state == .processing
      || oldValue.state == .notFound
    let duration = newValue.animated && animatedTransition ? 0.5 : 0.0
    let delayReset = oldValue.state == .processing || oldValue.state == .notFound

    if !delayReset {
      resetState()
    }

    if newValue.state != .processing {
      expandedConstraints.deactivate()
      collapsedConstraints.activate()
    } else {
      collapsedConstraints.deactivate()
      expandedConstraints.activate()
    }

    messageViewController.status = newValue

    UIView.animate(
      withDuration: duration,
      animations: ({
        self.view.layoutIfNeeded()
      }),
      completion: ({ [weak self] _ in
        if delayReset {
          self?.resetState()
        }

        self?.messageView.layer.removeAllAnimations()
        if self?.status.state == .processing {
          self?.messageViewController.animateLoading()
        }
      }))
  }

  /// Resets the current state.
  private func resetState() {
    locked = status.state == .processing && isOneTimeSearch
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
    add(childViewController: cameraViewController)
  }

  private func addHeaderIfNeeded() {
    guard let header = self.cameraHeaderVC else { return }
    add(childViewController: header)
    headerView.translatesAutoresizingMaskIntoConstraints = false
    view.bringSubviewToFront(headerView)
    //collapsedConstraints.activate()
  }

  private func addFooterIfNeeded() {
    guard let footer = self.footerVC else { return }
    add(childViewController: footer)
    footerView.translatesAutoresizingMaskIntoConstraints = false
    view.bringSubviewToFront(footerView)
  }

  // MARK: - Animations

  /**
   Simulates flash animation.
   - Parameter processing: Flag to set the current state to `.processing`.
   */
  private func animateFlash(whenProcessing: Bool = false) {
    guard shouldSimulateFlash else {
        if whenProcessing {
            self.status = Status(state: .processing)
        }
        return
    }

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
      completion: ({ [weak self] _ in
        flashView.removeFromSuperview()

        if whenProcessing {
          self?.status = Status(state: .processing)
        }
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
    let isFooterAvailable = self.footerVC != nil
    let isHeaderAvailable = self.cameraHeaderVC != nil

    NSLayoutConstraint.activate(
      cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      cameraView.bottomAnchor.constraint(equalTo: isFooterAvailable ? footerView.bottomAnchor : view.bottomAnchor),
      cameraView.topAnchor.constraint(equalTo: isHeaderAvailable ? headerView.topAnchor : view.topAnchor)
    )

    if navigationController != nil {
      cameraView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    } else {
      headerViewController.delegate = self
      add(childViewController: headerViewController)

      let headerView = headerViewController.view!

      NSLayoutConstraint.activate(
        headerView.topAnchor.constraint(equalTo: view.topAnchor),
        headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        headerView.bottomAnchor.constraint(equalTo: headerViewController.navigationBar.bottomAnchor),
        cameraView.topAnchor.constraint(equalTo: headerView.bottomAnchor)
      )
    }
  }

  private func makeExpandedConstraints() -> [NSLayoutConstraint] {
    return [
      messageView.topAnchor.constraint(equalTo: view.topAnchor),
      messageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      messageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      messageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ]
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

// MARK: - HeaderViewControllerDelegate

extension BarcodeScannerViewController: HeaderViewControllerDelegate {
  func headerViewControllerDidTapCloseButton(_ controller: HeaderViewController) {
    dismissalDelegate?.scannerDidDismiss(self)
  }
}

// MARK: - CameraViewControllerDelegate

extension BarcodeScannerViewController: CameraViewControllerDelegate {
  public func cameraViewControllerDidSetupCaptureSession(_ controller: CameraViewController) {
    status = Status(state: .scanning)
  }

  public func cameraViewControllerDidFailToSetupCaptureSession(_ controller: CameraViewController) {
    status = Status(state: .unauthorized)
  }

  public func cameraViewController(_ controller: CameraViewController, didReceiveError error: Error) {
    errorDelegate?.scanner(self, didReceiveError: .unexpected(error))
  }

  public func cameraViewControllerDidTapSettingsButton(_ controller: CameraViewController) {
    DispatchQueue.main.async {
      if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
      }
    }
  }

  public func cameraViewController(_ controller: CameraViewController,
                            didOutput metadataObjects: [AVMetadataObject]) {
    guard !locked && isVisible else { return }
    guard !metadataObjects.isEmpty else { return }

    guard
      let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject,
      var code = metadataObj.stringValue,
      metadata.contains(metadataObj.type)
      else { return }

    if isOneTimeSearch {
      locked = true
    }

    var rawType = metadataObj.type.rawValue

    // UPC-A is an EAN-13 barcode with a zero prefix.
    // See: https://stackoverflow.com/questions/22767584/ios7-barcode-scanner-api-adds-a-zero-to-upca-barcode-format
    if metadataObj.type == AVMetadataObject.ObjectType.ean13 && code.hasPrefix("0") {
      code = String(code.dropFirst())
      rawType = AVMetadataObject.ObjectType.upca.rawValue
    }

    codeDelegate?.scanner(self, didCaptureCode: code, type: rawType)
    animateFlash(whenProcessing: isOneTimeSearch)
  }
}
