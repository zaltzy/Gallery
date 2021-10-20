import UIKit
import Photos

/// Wrap a PHAsset
public class Image: Equatable {

    public enum ImageError: Error {
        case imageCreationFailed, imageResultIsInCloudKey
    }

  public let asset: PHAsset

  // MARK: - Initialization
  
  init(asset: PHAsset) {
    self.asset = asset
  }
}

// MARK: - UIImage with metadata typealias
public typealias UIImageData = (image: UIImage, metadata: [String: Any])

// MARK: - UIImage

extension Image {

  /// Resolve UIImage and it's metadata asynchronously
  /// - Parameters:
  ///   -  completion: A block to be called when the process is complete. The block takes the resolved UIImage and its CGImageMetadata
  ///    as parameters.
  public func resolveImageData(scale: CGFloat? = nil, completion: @escaping (Result<UIImageData, ImageError>) -> Void) {
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = true
    options.deliveryMode = .highQualityFormat
    PHImageManager.default().requestImageData(
        for: asset,
        options: options
    ) { [weak self] imageData, dataUTI, orientation, info in
      let destData = NSMutableData() as CFMutableData
      guard let imageData = imageData,
            let dataUTI = dataUTI,
            let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
            let imageDestination = CGImageDestinationCreateWithData(destData, dataUTI as CFString, 1, nil),
            let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        self?.completionWithError(info: info, completion: completion)
        return
      }
      CGImageDestinationAddImage(imageDestination, imageRef, nil)
      CGImageDestinationFinalize(imageDestination)
      guard var imageMetadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
            let generatedImage = UIImage(data: destData as Data),
            let cgImage = generatedImage.cgImage else {
        self?.completionWithError(info: info, completion: completion)
        return
      }
      self?.injectExifDate(to: &imageMetadata)
      var image = UIImage(cgImage: cgImage, scale: generatedImage.scale, orientation: orientation)
      if let scale = scale {
          let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
          let rect = CGRect(origin: .zero, size: newSize)
          UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
          image.draw(in: rect)
          if let newImage = UIGraphicsGetImageFromCurrentImageContext() {
            image = newImage
          }
          UIGraphicsEndImageContext()
      }
        completion(.success(UIImageData(image, imageMetadata)))
    }
  }

  private func completionWithError(info: [AnyHashable : Any]?, completion: @escaping (Result<UIImageData, ImageError>) -> Void) {
    if (info?[PHImageResultIsInCloudKey] as? NSNumber)?.boolValue == true {
        completion(.failure(.imageResultIsInCloudKey))
    } else {
        completion(.failure(.imageCreationFailed))
    }
  }

  private func injectExifDate(to imageMetadata: inout [String: Any]) {
    guard var exif = imageMetadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
          let creationDate = asset.creationDate else {
            return
          }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    if exif[kCGImagePropertyExifDateTimeOriginal as String] == nil {
      exif[kCGImagePropertyExifDateTimeOriginal as String] = formatter.string(from: creationDate)
    }

    if exif[kCGImagePropertyExifDateTimeDigitized as String] == nil {
      exif[kCGImagePropertyExifDateTimeDigitized as String] = formatter.string(from: creationDate)
    }
    imageMetadata[kCGImagePropertyExifDictionary as String] = exif
  }

  /// Resolve UIImage asynchronously
  /// - Parameters:
  ///   - completion: A block to be called when image resolving is complete. The block takes the resolved UIImage as a parameter.
  public func resolve(completion: @escaping (UIImage?) -> Void) {
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = true
    options.deliveryMode = .highQualityFormat

    PHImageManager.default().requestImage(
      for: asset,
      targetSize: PHImageManagerMaximumSize,
      contentMode: .default,
      options: options) { (image, _) in
      completion(image)
    }
  }

  /// Resolve an array of Images and their metadata
  /// - Parameters:
  ///   - images: The array of Images
  ///   -  completion: A block to be called when the process is complete. The block takes the array of resolved UIImages and their
  ///    CGImageMetadata as parameters.
  public static func resolveImageData(
    images: [Image],
    scale: CGFloat? = nil,
    completion: @escaping ([Result<UIImageData, ImageError>]) -> Void
  ) {
    let dispatchGroup = DispatchGroup()
    var convertedImages = [Int: Result<UIImageData, ImageError>]()

    for (index, image) in images.enumerated() {
      dispatchGroup.enter()

     image.resolveImageData(scale: scale) { result in
         convertedImages[index] = result
         dispatchGroup.leave()
     }
    }

    dispatchGroup.notify(queue: .main, execute: {
      let sortedImages = convertedImages
        .sorted(by: { $0.key < $1.key })
        .map({ $0.value })
      completion(sortedImages)
    })
  }

  /// Resolve an array of Images
  /// - Parameters:
  ///   - images: The array of Images
  ///   - completion: A block to be called when the process is complete. The block takes the array of resolved UIImages as a parameter.
  public static func resolve(images: [Image], completion: @escaping ([UIImage?]) -> Void) {
    let dispatchGroup = DispatchGroup()
    var convertedImages = [Int: UIImage]()

    for (index, image) in images.enumerated() {
      dispatchGroup.enter()

      image.resolve(completion: { resolvedImage in
        if let resolvedImage = resolvedImage {
          convertedImages[index] = resolvedImage
        }

        dispatchGroup.leave()
      })
    }

    dispatchGroup.notify(queue: .main, execute: {
      let sortedImages = convertedImages
        .sorted(by: { $0.key < $1.key })
        .map({ $0.value })
      completion(sortedImages)
    })
  }
}

// MARK: - Equatable

public func == (lhs: Image, rhs: Image) -> Bool {
  return lhs.asset == rhs.asset
}
