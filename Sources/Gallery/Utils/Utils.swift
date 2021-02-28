import UIKit
import AVFoundation
import Photos

struct Utils {

  static func rotationTransform() -> CGAffineTransform {
    switch UIDevice.current.orientation {
    case .landscapeLeft:
      return CGAffineTransform(rotationAngle: CGFloat(Double.pi/2))
    case .landscapeRight:
      return CGAffineTransform(rotationAngle: CGFloat(-Double.pi/2))
    case .portraitUpsideDown:
      return CGAffineTransform(rotationAngle: CGFloat(Double.pi))
    default:
      return CGAffineTransform.identity
    }
  }

  static func videoOrientation() -> AVCaptureVideoOrientation {
    if UIDevice.current.userInterfaceIdiom == .phone {
        return .portrait
    } else {
        switch UIApplication.shared.statusBarOrientation {
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .landscapeLeft
        }
    }
  }

  static func fetchOptions() -> PHFetchOptions {
    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

    return options
  }

  static func format(_ duration: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.zeroFormattingBehavior = .pad

    if duration >= 3600 {
      formatter.allowedUnits = [.hour, .minute, .second]
    } else {
      formatter.allowedUnits = [.minute, .second]
    }

    return formatter.string(from: duration) ?? ""
  }
}
