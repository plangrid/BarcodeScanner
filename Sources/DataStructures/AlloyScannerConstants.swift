//
//  AlloyScannerConstants.swift
//  BarcodeScanner-iOS
//
//  Created by Marco Emilio Vazquez Calva on 20/01/22.
//  Copyright © 2022 Hyper Interaktiv AS. All rights reserved.
//

import UIKit

enum AlloyScannerConstants {
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

  enum RectOfInterest {
    static let widthPercentage: CGFloat = 0.80
    static let heightPercentage: CGFloat = 0.20
    static let middle: CGFloat = 2.0
  }

  enum LayoutConstants {
    static let multiScanViewTop: CGFloat = 44
    static let multiScanViewHeight: CGFloat = 60
    static let flashButtonTop: CGFloat = 10
    static let flashButtonLeading: CGFloat = -16
    static let viewHeightPercentage: CGFloat = 4.8
  }
}
