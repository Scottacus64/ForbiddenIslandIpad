import SwiftUI
import UIKit

struct BundleImage: View {
    let name: String
    var contentMode: ContentMode = .fit
    var backgroundColor: UIColor? = nil
    var interpolation: Image.Interpolation = .high
    var renderedSize: CGSize? = nil
    var renderedContentMode: ContentMode = .fit
    var trimTransparentPadding: Bool = false
    var forceOpaqueRendering: Bool = false

    var body: some View {
        if let image = imageForDisplay {
            if renderedSize == nil {
                Image(uiImage: image)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(interpolation)
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(uiImage: image)
                    .renderingMode(.original)
                    .interpolation(interpolation)
            }
        } else {
            Rectangle()
                .fill(.black.opacity(0.18))
                .overlay {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
        }
    }

    private var imageForDisplay: UIImage? {
        guard let source = BundleImageCache.shared.image(named: name) else {
            return nil
        }

        let preparedSource = trimTransparentPadding ? source.trimmedTransparentPadding() : source
        let opaqueSource = forceOpaqueRendering
            ? preparedSource.flattened(on: preparedSource.estimatedOpaqueBackgroundColor() ?? .white)
            : preparedSource

        guard let renderedSize else {
            return backgroundColor.map { opaqueSource.flattened(on: $0) } ?? opaqueSource
        }

        return BundleImageCache.shared.renderedImage(
            named: name,
            size: renderedSize,
            backgroundColor: backgroundColor,
            sourceOverride: opaqueSource,
            interpolation: interpolation,
            contentMode: renderedContentMode
        )
    }
}

final class BundleImageCache {
    static let shared = BundleImageCache()

    private var images: [String: UIImage] = [:]

    private init() {}

    func image(named name: String) -> UIImage? {
        if let image = images[name] {
            return image
        }

        let image = loadImage(named: name)
        images[name] = image
        return image
    }

    private func loadImage(named name: String) -> UIImage? {
        let candidates = [
            ("Resources/CardPNGs", "png"),
            ("Resources/CardPNGs", "jpg"),
            ("Resources/CardPNGs", "jpeg"),
            ("Resources/RulesBook", "jpg"),
            ("Resources/RulesBook", "png"),
            (nil, "png"),
            (nil, "jpg"),
            (nil, "jpeg")
        ]

        for candidate in candidates {
            if let url = Bundle.main.url(
                forResource: name,
                withExtension: candidate.1,
                subdirectory: candidate.0
            ),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }

        return UIImage(named: name)
    }

    func renderedImage(
        named name: String,
        size: CGSize,
        backgroundColor: UIColor?,
        sourceOverride: UIImage? = nil,
        interpolation: Image.Interpolation,
        contentMode: ContentMode = .fit
    ) -> UIImage? {
        let key = renderedKey(
            name: name,
            size: size,
            backgroundColor: backgroundColor,
            sourceOverrideSize: sourceOverride?.size,
            interpolation: interpolation,
            contentMode: contentMode
        )

        if let image = renderedImages[key] {
            return image
        }

        guard let source = sourceOverride ?? image(named: name) else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = backgroundColor != nil

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            let bounds = CGRect(origin: .zero, size: size)
            if let backgroundColor {
                backgroundColor.setFill()
                context.fill(bounds)
            }

            let drawRect = contentMode == .fill
                ? aspectFillRect(sourceSize: source.size, in: bounds)
                : aspectFitRect(sourceSize: source.size, in: bounds)
            source.draw(in: drawRect)
        }

        renderedImages[key] = image
        return image
    }

    private var renderedImages: [String: UIImage] = [:]

    private func renderedKey(
        name: String,
        size: CGSize,
        backgroundColor: UIColor?,
        sourceOverrideSize: CGSize?,
        interpolation: Image.Interpolation,
        contentMode: ContentMode
    ) -> String {
        let bg = backgroundColor.map { color in
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return "\(red)-\(green)-\(blue)-\(alpha)"
        } ?? "nil"
        let sourceSize = sourceOverrideSize.map { "\($0.width.rounded(toPlaces: 2))x\($0.height.rounded(toPlaces: 2))" } ?? "orig"
        return "\(name)|\(size.width.rounded(toPlaces: 2))x\(size.height.rounded(toPlaces: 2))|\(sourceSize)|\(bg)|\(interpolationKey(interpolation))|\(contentModeKey(contentMode))"
    }

    private func aspectFitRect(sourceSize: CGSize, in bounds: CGRect) -> CGRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
        let width = sourceSize.width * scale
        let height = sourceSize.height * scale
        let x = bounds.midX - (width / 2)
        let y = bounds.midY - (height / 2)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func aspectFillRect(sourceSize: CGSize, in bounds: CGRect) -> CGRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return bounds
        }

        let scale = max(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
        let width = sourceSize.width * scale
        let height = sourceSize.height * scale
        let x = bounds.midX - (width / 2)
        let y = bounds.midY - (height / 2)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func interpolationKey(_ interpolation: Image.Interpolation) -> String {
        switch interpolation {
        case .none: "none"
        case .low: "low"
        case .medium: "medium"
        case .high: "high"
        @unknown default: "unknown"
        }
    }

    private func contentModeKey(_ contentMode: ContentMode) -> String {
        switch contentMode {
        case .fit: "fit"
        case .fill: "fill"
        @unknown default: "unknown"
        }
    }
}

private extension UIImage {
    func estimatedOpaqueBackgroundColor() -> UIColor? {
        guard let cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            return nil
        }

        let bytesPerRow = width * 4
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let buffer = context.data else {
            return nil
        }

        let bytes = buffer.assumingMemoryBound(to: UInt8.self)
        var totalRed: Double = 0
        var totalGreen: Double = 0
        var totalBlue: Double = 0
        var totalWeight: Double = 0

        for y in 0..<height {
            for x in 0..<width {
                let index = y * bytesPerRow + (x * 4)
                let red = Double(bytes[index + 0]) / 255.0
                let green = Double(bytes[index + 1]) / 255.0
                let blue = Double(bytes[index + 2]) / 255.0
                let alpha = Double(bytes[index + 3]) / 255.0
                guard alpha > 0 else {
                    continue
                }

                totalRed += red * alpha
                totalGreen += green * alpha
                totalBlue += blue * alpha
                totalWeight += alpha
            }
        }

        guard totalWeight > 0 else {
            return nil
        }

        return UIColor(
            red: CGFloat(totalRed / totalWeight),
            green: CGFloat(totalGreen / totalWeight),
            blue: CGFloat(totalBlue / totalWeight),
            alpha: 1
        )
    }

    func trimmedTransparentPadding() -> UIImage {
        guard let cgImage else {
            return self
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            return self
        }

        let bytesPerRow = width * 4
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return self
        }

        let drawRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(cgImage, in: drawRect)

        guard let buffer = context.data else {
            return self
        }

        let bytes = buffer.assumingMemoryBound(to: UInt8.self)
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let alphaIndex = y * bytesPerRow + (x * 4) + 3
                if bytes[alphaIndex] > 0 {
                    if x < minX { minX = x }
                    if y < minY { minY = y }
                    if x > maxX { maxX = x }
                    if y > maxY { maxY = y }
                }
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return self
        }

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )

        guard let cropped = cgImage.cropping(to: cropRect) else {
            return self
        }

        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}

private extension UIImage {
    func flattened(on backgroundColor: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = scale

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private extension CGFloat {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return Double((self * CGFloat(factor)).rounded() / CGFloat(factor))
    }
}
