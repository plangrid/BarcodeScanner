//
//  CameraViewModel.swift
//  BarcodeScanner-iOS
//
//  Created by Marco Emilio Vazquez Calva on 20/12/21.
//  Copyright © 2021 Hyper Interaktiv AS. All rights reserved.
//

import Foundation
import UIKit

public protocol CameraViewModelProtocol {
  var flashButton: FlashButtonProtocol { get }
  var settingsButtonTitle: String { get }
  var cameraImage: UIImage? { get }
}

public protocol FlashButtonProtocol {
  var imageOn: UIImage? { get }
  var imageOff: UIImage? { get }
}

public struct DefaultFlashButton: FlashButtonProtocol {
  public let imageOn: UIImage? = UIImage(named: "flashOn")
  public let imageOff: UIImage? = UIImage(named: "flashOff")

  public init() {}
}

public struct DefaultCameraViewModel: CameraViewModelProtocol {
  public let flashButton: FlashButtonProtocol = DefaultFlashButton()
  public let settingsButtonTitle: String = localizedString("BUTTON_SETTINGS")
  public let cameraImage: UIImage? = UIImage(named: "cameraRotate")

  public init() {}
}
