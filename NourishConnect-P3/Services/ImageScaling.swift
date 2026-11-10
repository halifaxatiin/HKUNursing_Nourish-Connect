import UIKit
import ImageIO

/// Camera photos are 12 to 48 megapixels (about 50 to 190 MB once opened). The text reader and the
/// dish model need far less, so photos are made smaller before they are kept or analysed.
extension UIImage {
    /// A copy, turned upright, whose longer side is at most `maxSide` pixels. Runs off the main thread.
    func scaledDown(maxSide: CGFloat) async -> UIImage {
        let pixels = CGSize(width: size.width * scale, height: size.height * scale)
        let longest = max(pixels.width, pixels.height)
        guard longest > maxSide else { return self }

        let ratio = maxSide / longest
        let target = CGSize(width: (pixels.width * ratio).rounded(), height: (pixels.height * ratio).rounded())
        return await Task.detached(priority: .userInitiated) {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            return UIGraphicsImageRenderer(size: target, format: format).image { _ in
                self.draw(in: CGRect(origin: .zero, size: target))
            }
        }.value
    }

    /// Opens photo data straight at the smaller size, so the full-size photo is never held in memory.
    static func scaledDown(from data: Data, maxSide: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide
        ]
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
