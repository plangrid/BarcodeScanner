import UIKit
import AVFoundation

/// Wrapper around `AVCaptureTorchMode`.
public enum TorchMode {
  case on
  case off

  /// Returns the next torch mode.
  var next: TorchMode {
    switch self {
    case .on:
      return .off
    case .off:
      return .on
    }
  }

  /// Returns `AVCaptureTorchMode` value.
  var captureTorchMode: AVCaptureDevice.TorchMode {
    switch self {
    case .on:
      return .on
    case .off:
      return .off
    }
  }

  /// Torch mode image.
  func image(fromViewModel viewModel: FlashButtonProtocol) -> UIImage? {
    switch self {
    case .on:
      return imageNamed("flashOn")
    case .off:
      return imageNamed("flashOff")
    }
  }
}
