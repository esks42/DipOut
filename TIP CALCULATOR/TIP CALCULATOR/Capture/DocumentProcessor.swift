//
//  DocumentProcessor.swift
//  TIP CALCULATOR
//
//  Finds the receipt in a captured photo and flattens it (perspective-correct + crop), turning an
//  angled clipboard/table shot into a clean head-on document — the same thing VisionKit's document
//  scanner does internally. Applied only to single-receipt camera captures, where detection is
//  reliable; the user sees the flattened result and can retake if it cropped wrong.
//

import UIKit
import Vision
import CoreImage

nonisolated enum DocumentProcessor {
    private static let context = CIContext()

    /// Returns the deskewed, cropped receipt, or `nil` when no plausible document is found.
    static func flattened(_ image: UIImage) -> UIImage? {
        return autoreleasepool {
            guard let cg = image.cgImage else { return nil }

            let request = VNDetectDocumentSegmentationRequest()
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
            try? handler.perform([request])
            guard let doc = request.results?.first else { return nil }

            // Ignore an implausible quad (tiny, or essentially the whole frame = nothing detected).
            let area = quadArea(doc)
            guard area > 0.10, area < 0.99 else { return nil }

            let ci = CIImage(cgImage: cg)
            let w = ci.extent.width, h = ci.extent.height
            func point(_ p: CGPoint) -> CIVector { CIVector(x: p.x * w, y: p.y * h) }

            guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
            filter.setValue(ci, forKey: kCIInputImageKey)
            filter.setValue(point(doc.topLeft), forKey: "inputTopLeft")
            filter.setValue(point(doc.topRight), forKey: "inputTopRight")
            filter.setValue(point(doc.bottomLeft), forKey: "inputBottomLeft")
            filter.setValue(point(doc.bottomRight), forKey: "inputBottomRight")

            guard let output = filter.outputImage,
                  let result = context.createCGImage(output, from: output.extent) else { return nil }
            return UIImage(cgImage: result)
        }
    }

    private static func quadArea(_ r: VNRectangleObservation) -> CGFloat {
        let pts = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft]
        var sum: CGFloat = 0
        for i in 0..<pts.count {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }
}
