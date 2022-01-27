//
//  CameraControllerProtocol.swift
//  BarcodeScanner-iOS
//
//  Created by Marco Emilio Vazquez Calva on 18/01/22.
//  Copyright © 2022 Hyper Interaktiv AS. All rights reserved.
//

import AVFoundation
import Foundation
import UIKit

/// Protocol used to make camera controllers generics
protocol CameraControllerProtocol {
  var metadata: [AVMetadataObject.ObjectType] { get set }
  var delegate: CameraViewControllerDelegate? { get set }
  var multiScanDelegate: MultiScanProtocol? { get set }
  func startCapturing()
  func stopCapturing()
}

/// Enum to handle camera controllers
public enum CameraViewType {
  /// This type is used for the old CameraViewController and it's the default value
  case normal
  /// This type is used for the camera UI defined for alloy
  /// - Parameter config: A protocol used to configure the view
  case alloy(config: CameraViewConfigurationProtocol)

  var controller: CameraControllerProtocol {
    switch self {
    case .normal:
      return CameraViewController()
    case let .alloy(configuration):
      return AlloyScannerViewController(configuration: configuration)
    }
  }
}

public protocol CameraViewConfigurationProtocol {
  var focusViewStrokeColor: UIColor { get }
  var isMultiScanEnabled: Bool { get }
  var multiScanTitle: NSAttributedString { get }
  var descriptionText: NSAttributedString { get }
}

public struct CameraViewConfiguration: CameraViewConfigurationProtocol {
  public var focusViewStrokeColor: UIColor
  public var isMultiScanEnabled: Bool
  public var multiScanTitle: NSAttributedString
  public var descriptionText: NSAttributedString

  public init(
    focusViewStrokeColor: UIColor = .white,
    isMultiScanEnabled: Bool = false,
    multiScanTitle: NSAttributedString,
    descriptionText: NSAttributedString
  ) {
    self.focusViewStrokeColor = focusViewStrokeColor
    self.isMultiScanEnabled = isMultiScanEnabled
    self.multiScanTitle = multiScanTitle
    self.descriptionText = descriptionText
  }
}
