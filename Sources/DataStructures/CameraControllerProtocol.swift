//
//  CameraControllerProtocol.swift
//  BarcodeScanner-iOS
//
//  Created by Marco Emilio Vazquez Calva on 18/01/22.
//  Copyright © 2022 Hyper Interaktiv AS. All rights reserved.
//

import AVFoundation
import Foundation

public protocol CameraControllerProtocol {
  var metadata: [AVMetadataObject.ObjectType] { get set }
  var delegate: CameraViewControllerDelegate? { get set }
  func startCapturing()
  func stopCapturing()
}

public enum CameraViewType {
  case normal
  case alloy

  var controller: CameraControllerProtocol {
    switch self {
    case .normal:
      return CameraViewController()
    case .alloy:
      return AlloyScannerViewController()
    }
  }
}
