import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO

struct ProcessOptions {
    var quad: Quad?
    var rotation: Int
    var forceA6: Bool
    var jpegQuality: Double
}

enum ImageProcessor {
    private static let context = CIContext()
    private static let a6Ratio: CGFloat = 148.0 / 105.0

    static func jpeg(from image: CIImage, options: ProcessOptions) -> Data? {
        var output = image

        // 台形補正 + トリム
        if let quad = options.quad {
            let e = image.extent
            func p(_ v: CGPoint) -> CGPoint {
                CGPoint(x: e.minX + v.x * e.width, y: e.minY + v.y * e.height)
            }
            let filter = CIFilter.perspectiveCorrection()
            filter.inputImage = image
            filter.topLeft = p(quad.topLeft)
            filter.topRight = p(quad.topRight)
            filter.bottomRight = p(quad.bottomRight)
            filter.bottomLeft = p(quad.bottomLeft)
            filter.crop = true
            if let corrected = filter.outputImage {
                output = corrected
            }
        }

        output = rotate(output, degrees: options.rotation)

        if options.forceA6 && options.quad != nil {
            output = fitToA6(output)
        }

        // 原点を (0,0) に揃え、端数ピクセルを落とす
        output = output.transformed(by: CGAffineTransform(translationX: -output.extent.minX, y: -output.extent.minY))
        output = output.cropped(to: CGRect(x: 0, y: 0, width: floor(output.extent.width), height: floor(output.extent.height)))

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let qualityKey = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        return context.jpegRepresentation(of: output, colorSpace: colorSpace, options: [qualityKey: options.jpegQuality])
    }

    /// 時計回りに回転
    private static func rotate(_ image: CIImage, degrees: Int) -> CIImage {
        switch ((degrees % 360) + 360) % 360 {
        case 90: image.oriented(.right)
        case 180: image.oriented(.down)
        case 270: image.oriented(.left)
        default: image
        }
    }

    /// 長辺を保ったまま A6 の縦横比 (105:148) に伸縮する
    private static func fitToA6(_ image: CIImage) -> CIImage {
        let w = image.extent.width, h = image.extent.height
        guard w > 0, h > 0 else { return image }
        let transform: CGAffineTransform
        if h >= w {
            transform = CGAffineTransform(scaleX: (h / a6Ratio) / w, y: 1)
        } else {
            transform = CGAffineTransform(scaleX: 1, y: (w / a6Ratio) / h)
        }
        return image.samplingLinear().transformed(by: transform)
    }
}
