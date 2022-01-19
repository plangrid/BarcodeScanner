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
  var metadata: [AVMetadataObject.ObjectType] = [AVMetadataObject.ObjectType]()
  var delegate: CameraViewControllerDelegate?

  func startCapturing() {
    self.captureSession.startRunning()
  }

  func stopCapturing() {
    self.captureSession.stopRunning()
  }

  // MARK: - Properties
  private var captureSession = AVCaptureSession()
  private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
  private var captureMetadataOutput = AVCaptureMetadataOutput()
  private var focusView: UIView?
  private var borderShapeLayer: CAShapeLayer?

  override func viewDidLoad() {
    super.viewDidLoad()
    initBarCode()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.startReadingAnimation()
    self.setupRectOfInterest()
  }

  private func initBarCode() {
    guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
      print("Failed to get camera device")
      return
    }

    do {
      let input = try AVCaptureDeviceInput(device: captureDevice)
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
      addTransparentOverlayWithCirlce()
    } catch {
      print(error)
      return
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
}

extension AlloyScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    captureSession.stopRunning()
    // Check if the metadata array is not nil and it containts at least one object
    if let metadataObject = metadataObjects.first {
      guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
      guard let stringValue = readableObject.stringValue else { return }
      AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
      print(stringValue)
    }
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

  func addTransparentOverlayWithCirlce() {
    self.focusView = createOverlay()
    if let focusView = self.focusView {
      view.addSubview(focusView)
      self.view.bringSubviewToFront(focusView)
    }
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

  private func startLoadingAnimation() {
  }

  private func stopAnimations() {
    borderShapeLayer?.removeAllAnimations()
  }
}

enum BarCodeConstants {
  enum BoundingBox {
    static let horizontalPadding: CGFloat = 0.65
    static let verticalPadding: CGFloat = 0.30
    static let middle: CGFloat = 2.0
    static let cornerSize: CGFloat = 5.0
    static let borderWidth: CGFloat = 5.0
  }

  enum ReadingAnimation {
    static let fromValue: CGFloat = 0.0
    static let toValue: CGFloat = 1.0
    static let duration: TimeInterval = 0.8
  }
}
