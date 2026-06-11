//
//  OCRService.swift
//  TIP CALCULATOR
//
//  Thin wrapper over Vision text recognition. Runs off the main thread.
//
//  Receipts picked from Photos arrive at arbitrary rotations (EXIF, or laid sideways on a table),
//  and Vision reads `cgImage` in raw pixel orientation — so we recognise at all four orientations
//  and keep whichever yields the most confident, most currency-shaped text. This is the single
//  biggest factor in getting usable text out of real phone photos.
//

import Foundation
import Vision
import UIKit

enum OCRService {
    /// Recognise the receipt text in an image, newline-separated in reading order.
    static func recognizeText(in image: UIImage) async -> String {
        let downscaled = downscale(image)
        guard let cgImage = downscaled.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: bestAcrossOrientations(cgImage).text)
            }
        }
    }

    private static func downscale(_ image: UIImage, maxDimension: CGFloat = 1800) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        
        let aspectRatio = size.width / size.height
        let targetSize: CGSize
        if size.width > size.height {
            targetSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            targetSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Keep exact pixel dimensions
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private static func bestAcrossOrientations(_ cgImage: CGImage) -> (text: String, score: Double) {
        let orientations: [CGImagePropertyOrientation] = [.up, .right, .down, .left]
        return orientations
            .map { recognize(cgImage, orientation: $0) }
            .max { $0.score < $1.score } ?? ("", 0)
    }

    private static func recognize(_ cgImage: CGImage,
                                  orientation: CGImagePropertyOrientation) -> (text: String, score: Double) {
        return autoreleasepool {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try? handler.perform([request])

            let candidates = (request.results ?? []).compactMap { $0.topCandidates(1).first }
            let text = candidates.map(\.string).joined(separator: "\n")
            // Reward total confidence, and weight currency-shaped tokens — the upright pass yields
            // far more clean "12.34" matches than a rotated one.
            let confidence = candidates.map { Double($0.confidence) }.reduce(0, +)
            let moneyTokens = Double(text.matches(of: /\d+[.,]\d{2}/).count)
            return (text, confidence + moneyTokens * 5)
        }
    }
}
