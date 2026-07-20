//
//  AutoAdjustmentService.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 18.07.2026.
//

import CoreImage
import CoreImage.CIFilterBuiltins

final class AutoAdjustmentService {

    private let histogramBinCount = 256

    private let context = CIContext(options: [
        .cacheIntermediates: false
    ])

    func makeRecipe(
        for image: CIImage,
        baseRecipe: EditRecipe
    ) -> EditRecipe {
        guard let histogram = makeLuminanceHistogram(for: image) else {
            return makeFallbackRecipe(from: baseRecipe)
        }

        let meanLuminance = histogram.enumerated().reduce(Float.zero) { partialResult, item in
            let normalizedPosition = Float(item.offset)
                / Float(histogramBinCount - 1)

            return partialResult
                + normalizedPosition * item.element
        }

        let shadowsShare = histogram[0..<64].reduce(0, +)
        let highlightsShare = histogram[192..<256].reduce(0, +)

        let clippedShadowsShare = histogram[0..<8].reduce(0, +)
        let clippedHighlightsShare = histogram[248..<256].reduce(0, +)

        var recipe = baseRecipe

        recipe.brightness = 0

        recipe.exposure = clamped(
            (0.48 - meanLuminance) * 1.4,
            lower: -0.45,
            upper: 0.45
        )

        recipe.contrast = 1.05

        recipe.shadows = clamped(
            0.18
                + shadowsShare * 0.9
                + clippedShadowsShare * 1.5,
            lower: 0.18,
            upper: 0.72
        )

        recipe.highlights = -clamped(
            0.12
                + highlightsShare * 0.75
                + clippedHighlightsShare * 1.5,
            lower: 0.12,
            upper: 0.62
        )

        recipe.whites = clamped(
            0.08 - clippedHighlightsShare * 3.5,
            lower: -0.20,
            upper: 0.08
        )

        recipe.blacks = clamped(
            -0.06 + clippedShadowsShare * 2.5,
            lower: -0.06,
            upper: 0.14
        )

        recipe.vibrance = 0.20
        recipe.saturation = 1.05
        recipe.sharpen = 0.35

        return recipe
    }

    private func makeLuminanceHistogram(
        for image: CIImage
    ) -> [Float]? {
        guard !image.extent.isEmpty, !image.extent.isInfinite else { return nil }

        let grayscaleFilter = CIFilter.colorControls()
        grayscaleFilter.inputImage = image
        grayscaleFilter.saturation = 0
        grayscaleFilter.brightness = 0
        grayscaleFilter.contrast = 1

        guard let grayscaleImage = grayscaleFilter.outputImage else {
            return nil
        }

        let histogramFilter = CIFilter.areaHistogram()
        histogramFilter.inputImage = grayscaleImage
        histogramFilter.extent = grayscaleImage.extent
        histogramFilter.count = histogramBinCount
        histogramFilter.scale = 1

        guard let histogramImage = histogramFilter.outputImage else {
            return nil
        }

        let componentsPerPixel = 4
        let bytesPerComponent = MemoryLayout<Float>.size
        let rowBytes = histogramBinCount
            * componentsPerPixel
            * bytesPerComponent

        var bitmap = [Float](
            repeating: 0,
            count: histogramBinCount * componentsPerPixel
        )

        let renderBounds = CGRect(
            x: 0,
            y: 0,
            width: histogramBinCount,
            height: 1
        )

        bitmap.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return
            }

            context.render(
                histogramImage,
                toBitmap: baseAddress,
                rowBytes: rowBytes,
                bounds: renderBounds,
                format: .RGBAf,
                colorSpace: nil
            )
        }

        let histogram = (0..<histogramBinCount).map { index in
            max(bitmap[index * componentsPerPixel], 0)
        }

        let total = histogram.reduce(0, +)

        guard total > 0 else {
            return nil
        }

        return histogram.map {
            $0 / total
        }
    }

    private func makeFallbackRecipe(
        from baseRecipe: EditRecipe
    ) -> EditRecipe {
        var recipe = baseRecipe

        recipe.brightness = 0
        recipe.contrast = 1.05
        recipe.exposure = 0

        recipe.shadows = 0.38
        recipe.highlights = -0.32
        recipe.whites = 0.05
        recipe.blacks = -0.04

        recipe.vibrance = 0.20
        recipe.saturation = 1.05
        recipe.sharpen = 0.35

        return recipe
    }

    private func clamped(
        _ value: Float,
        lower: Float,
        upper: Float
    ) -> Float {
        max(
            lower,
            min(value, upper)
        )
    }
}
