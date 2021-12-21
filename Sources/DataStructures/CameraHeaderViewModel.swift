//
//  CameraHeaderViewModel.swift
//  BarcodeScanner-iOS
//
//  Created by Marco Emilio Vazquez Calva on 20/12/21.
//  Copyright © 2021 Hyper Interaktiv AS. All rights reserved.
//

import Foundation
import UIKit

public protocol CameraHeaderViewProtocol {
  var title: String { get }
  var barCodeSubtitle: String { get }
  var qrSubtitle: String { get }
  var barcodeImage: UIImage? { get }
  var qrImage: UIImage? { get }
}

public struct DefaultCameraHeaderViewModel: CameraHeaderViewProtocol {
  public let title: String = localizedString("SCAN_TITLE")
  public let barCodeSubtitle: String = localizedString("SCAN_BARCODE_SUBTITLE")
  public let qrSubtitle: String = localizedString("SCAN_QRCODE_SUBTITLE")
  public let barcodeImage: UIImage? = UIImage(named: "barcode")
  public let qrImage: UIImage? = UIImage(named: "qrcode")

  public init() {}
}
