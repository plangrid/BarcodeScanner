//
//  BarcodeScannerModel.swift
//  BarcodeScanner-iOS
//
//  Created by Marco Emilio Vazquez Calva on 18/01/22.
//  Copyright © 2022 Hyper Interaktiv AS. All rights reserved.
//

import Foundation

// MARK: - Delegates
/// Delegate to handle the captured code.
public protocol BarcodeScannerCodeDelegate: AnyObject {
  func scanner(
    _ controller: BarcodeScannerViewController,
    didCaptureCode code: String,
    type: String
  )
}

/// Delegate to report errors.
public protocol BarcodeScannerErrorDelegate: AnyObject {
  func scanner(_ controller: BarcodeScannerViewController, didReceiveError error: BarcodeScannerError)
}

/// Delegate to dismiss barcode scanner when the close button has been pressed.
public protocol BarcodeScannerDismissalDelegate: AnyObject {
  func scannerDidDismiss(_ controller: BarcodeScannerViewController)
}

// MARK: - Error types
public enum BarcodeScannerError: Error {
  /// Error when something besides a MachineReadableCodeObject was detected. (Check AVMetadataObject.ObjectType documentation)
  case nonMachineReadableCodeDetected
  /// Error describing an unexpected/general error
  case unexpected(Error)
  /// Error when a MachineReadableCodeObject was detected but its metadata is unsupported
  case unsupported
}
