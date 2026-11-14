import Photos
import UIKit
import Vision

/// Errors from fetching the latest screenshot and reading its text.
public enum ScreenshotError: Error, LocalizedError {
    /// The user has not granted Photos access (or denied it).
    case photosDenied
    /// No screenshot was found in the photo library.
    case noScreenshot
    /// The asset existed but its image data could not be loaded.
    case imageUnavailable
    /// Vision OCR produced no usable text.
    case ocrFailed

    public var errorDescription: String? {
        switch self {
        case .photosDenied:
            return "Photos access is off. Allow Photos access in Settings to use screenshots."
        case .noScreenshot:
            return "No screenshot found. Take a screenshot of the chat first, then try again."
        case .imageUnavailable:
            return "Could not load the latest screenshot. Please try again."
        case .ocrFailed:
            return "Could not read any text from the screenshot. Try a clearer screenshot."
        }
    }
}

/// Fetches the latest screenshot from Photos and reads its chat text
/// on-device with Vision OCR. The image itself never leaves the device.
public struct ScreenshotService {

    public init() {}

    /// Returns the latest screenshot asset, or nil when there is none.
    /// - Note: Callers must already hold Photos permission. Use
    ///   `PHPhotoLibrary.requestAuthorization(for: .readWrite)` in the
    ///   container app; in the keyboard extension, Photos access also
    ///   requires Allow Full Access.
    public func latestScreenshotAsset() -> PHAsset? {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        options.predicate = NSPredicate(
            format: "mediaSubtype == %d",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        let result = PHAsset.fetchAssets(with: .image, options: options)
        return result.firstObject
    }

    /// Loads a UIImage for the given asset.
    public func image(for asset: PHAsset) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ScreenshotError.imageUnavailable)
                }
            }
        }
    }

    /// Reads text from an image with on-device Vision OCR.
    public func recognizeText(in image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else {
            throw ScreenshotError.ocrFailed
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw ScreenshotError.ocrFailed
        }
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            throw ScreenshotError.ocrFailed
        }
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw ScreenshotError.ocrFailed
        }
        return text
    }

    /// Fetches the latest screenshot and returns its OCR text.
    /// Throws `ScreenshotError.photosDenied` when Photos is not authorised.
    public func latestScreenshotTranscript() async throws -> String {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw ScreenshotError.photosDenied
        }
        guard let asset = latestScreenshotAsset() else {
            throw ScreenshotError.noScreenshot
        }
        let image = try await image(for: asset)
        return try recognizeText(in: image)
    }
}
