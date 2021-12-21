//
//  FooterViewModel.swift
//  BarcodeScanner-iOS
//
//  Created by Marco Emilio Vazquez Calva on 20/12/21.
//  Copyright © 2021 Hyper Interaktiv AS. All rights reserved.
//

import Foundation
import UIKit

public protocol FooterViewModelProtocol {
  var backgroundColor: UIColor { get }
  var cancelButtonViewModel: ButtonStyleProtocol { get }
}

public protocol ButtonStyleProtocol {
  var title: String { get }
  var fontColor: UIColor { get }
  var font: UIFont? { get }
}

public struct DefaultCancelButton: ButtonStyleProtocol {
  public let title: String = localizedString("BUTTON_CLOSE")
  public let fontColor: UIColor = .white
  public let font: UIFont? = UIFont(name: "ArtifaktElement-Regular", size: 18)

  public init() {}
}

public struct DefaultFooterViewModel: FooterViewModelProtocol {
  public let backgroundColor: UIColor = .black
  public let cancelButtonViewModel: ButtonStyleProtocol = DefaultCancelButton()

  public init() {}
}
