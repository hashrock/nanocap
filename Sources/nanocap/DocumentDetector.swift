import CoreImage
import Vision

/// Vision の矩形検出で A6 ノート（短辺:長辺 ≒ 0.71）を探す
enum DocumentDetector {
    static func detect(in pixelBuffer: CVPixelBuffer) -> Quad? {
        perform(VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]))
    }

    static func detect(in image: CIImage) -> Quad? {
        perform(VNImageRequestHandler(ciImage: image, options: [:]))
    }

    private static func perform(_ handler: VNImageRequestHandler) -> Quad? {
        let request = VNDetectRectanglesRequest()
        // A6 単ページ・見開き (A5) ともに約 0.707。傾きによる歪みを見込んで幅を持たせる
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 0.95
        request.minimumSize = 0.2
        request.quadratureTolerance = 30
        request.minimumConfidence = 0.6
        request.maximumObservations = 1
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        return request.results?.first.map(Quad.init)
    }
}
