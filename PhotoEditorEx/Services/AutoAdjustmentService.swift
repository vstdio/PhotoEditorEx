//
//  AutoAdjustmentService.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 18.07.2026.
//

import CoreImage
import CoreImage.CIFilterBuiltins

final class AutoAdjustmentService {

    private struct LuminanceStatistics {

        let mean: Float
        let standardDeviation: Float

        let percentile10: Float
        let median: Float
        let percentile90: Float
        let percentile95: Float
        let percentile99: Float

        let clippedShadowsShare: Float
        let shadowsShare: Float
        let highlightsShare: Float
        let nearWhiteShare: Float
        let clippedHighlightsShare: Float

        var isLowKey: Bool {
            median < 0.24 && percentile90 < 0.68
        }

        var isHighKey: Bool {
            median > 0.72 && percentile10 > 0.38
        }
    }

    private let histogramBinCount = 256
    private let analysisMaxPixelSize: CGFloat = 512

    private let context = CIContext(options: [
        .cacheIntermediates: false
    ])

    func makeRecipe(for image: CIImage, baseRecipe: EditRecipe) -> EditRecipe {
        guard
            let histogram = makeLuminanceHistogram(for: image),
            let statistics = makeStatistics(from: histogram)
        else {
            return makeFallbackRecipe(from: baseRecipe)
        }

        let shadowsAdjustment = makeShadowsAdjustment(from: statistics)
        let highlightsAdjustment = makeHighlightsAdjustment(from: statistics)
        let exposureAdjustment = makeExposureAdjustment(from: statistics)

        let contrastMultiplier = makeContrastMultiplier(
            from: statistics,
            shadowsAdjustment: shadowsAdjustment,
            highlightsAdjustment: highlightsAdjustment
        )

        let blacksAdjustment = makeBlacksAdjustment(
            from: statistics,
            shadowsAdjustment: shadowsAdjustment
        )

        let whitesAdjustment = makeWhitesAdjustment(
            from: statistics,
            highlightsAdjustment: highlightsAdjustment
        )

        var recipe = baseRecipe

        recipe.exposure = clamped(
            baseRecipe.exposure + exposureAdjustment,
            lower: -2,
            upper: 2
        )

        recipe.shadows = clamped(
            baseRecipe.shadows + shadowsAdjustment,
            lower: -1,
            upper: 1
        )

        recipe.highlights = clamped(
            baseRecipe.highlights + highlightsAdjustment,
            lower: -1,
            upper: 1
        )

        recipe.blacks = clamped(
            baseRecipe.blacks + blacksAdjustment,
            lower: -1,
            upper: 1
        )

        recipe.whites = clamped(
            baseRecipe.whites + whitesAdjustment,
            lower: -1,
            upper: 1
        )

        recipe.contrast = clamped(
            baseRecipe.contrast * contrastMultiplier,
            lower: 0.5,
            upper: 2
        )

        recipe.vibrance = clamped(
            baseRecipe.vibrance + makeVibranceAdjustment(from: statistics),
            lower: -1,
            upper: 1
        )

        recipe.sharpen = max(
            baseRecipe.sharpen,
            makeSharpenAdjustment(from: statistics)
        )

        return recipe
    }

    private func makeShadowsAdjustment(from statistics: LuminanceStatistics) -> Float {
        guard statistics.shadowsShare > 0.18 else {
            return 0
        }

        guard statistics.percentile10 < 0.13 else {
            return 0
        }

        let percentileNeed = normalized(
            0.13 - statistics.percentile10,
            maximum: 0.13
        )

        let shadowsShareNeed = normalized(
            statistics.shadowsShare - 0.18,
            maximum: 0.34
        )

        var adjustment =
            0.06
            + percentileNeed * 0.16
            + shadowsShareNeed * 0.10

        if statistics.isLowKey {
            adjustment *= 0.45
        } else if statistics.mean < 0.30 {
            adjustment *= 0.75
        }

        if statistics.clippedShadowsShare > 0.08 {
            adjustment = min(adjustment, 0.20)
        }

        return clamped(adjustment, lower: 0, upper: 0.32)
    }

    private func makeHighlightsAdjustment(from statistics: LuminanceStatistics) -> Float {
        let hasBroadBrightArea =
            statistics.highlightsShare > 0.06
            && statistics.percentile90 > 0.82

        let hasNearWhiteArea =
            statistics.nearWhiteShare > 0.012
            && statistics.percentile95 > 0.92

        let hasClippedArea =
            statistics.clippedHighlightsShare > 0.004
            && statistics.percentile99 > 0.985

        guard hasBroadBrightArea || hasNearWhiteArea || hasClippedArea else {
            return 0
        }

        let percentileNeed = normalized(
            statistics.percentile90 - 0.82,
            maximum: 0.16
        )

        let highlightsShareNeed = normalized(
            statistics.highlightsShare - 0.06,
            maximum: 0.28
        )

        let nearWhiteNeed = normalized(
            statistics.nearWhiteShare - 0.012,
            maximum: 0.10
        )

        let clippedHighlightsNeed = normalized(
            statistics.clippedHighlightsShare - 0.004,
            maximum: 0.05
        )

        var adjustment =
            0.06
            + percentileNeed * 0.16
            + highlightsShareNeed * 0.10
            + nearWhiteNeed * 0.10
            + clippedHighlightsNeed * 0.08

        if statistics.isHighKey {
            adjustment *= 0.65
        }

        if statistics.clippedHighlightsShare > 0.10 {
            adjustment = min(adjustment, 0.34)
        }

        return -clamped(adjustment, lower: 0.08, upper: 0.50)
    }

    private func makeExposureAdjustment(from statistics: LuminanceStatistics) -> Float {
        let hasClippedHighlights = statistics.clippedHighlightsShare > 0.025
        let hasLargeNearWhiteArea = statistics.nearWhiteShare > 0.08
        let hasAlmostNoHeadroom = statistics.percentile95 > 0.96

        guard !hasClippedHighlights,
              !hasLargeNearWhiteArea,
              !hasAlmostNoHeadroom else {
            return 0
        }

        guard statistics.median < 0.42 else {
            return 0
        }

        let medianNeed = normalized(
            0.42 - statistics.median,
            maximum: 0.30
        )

        let meanNeed = normalized(
            0.40 - statistics.mean,
            maximum: 0.30
        )

        let upperRangeNeed = normalized(
            0.82 - statistics.percentile90,
            maximum: 0.40
        )

        var adjustment =
            0.04
            + medianNeed * 0.26
            + meanNeed * 0.08
            + upperRangeNeed * 0.06

        let highlightHeadroom = normalized(
            0.96 - statistics.percentile95,
            maximum: 0.26
        )

        let headroomMultiplier =
            0.55
            + highlightHeadroom * 0.45

        adjustment *= headroomMultiplier

        if statistics.isLowKey {
            adjustment *= 0.80
        }

        return clamped(adjustment, lower: 0, upper: 0.38)
    }

    private func makeContrastMultiplier(
        from statistics: LuminanceStatistics,
        shadowsAdjustment: Float,
        highlightsAdjustment: Float
    ) -> Float {
        let toneCompression = shadowsAdjustment + abs(highlightsAdjustment)

        var multiplier: Float

        if statistics.standardDeviation < 0.16,
           !statistics.isLowKey,
           !statistics.isHighKey {
            multiplier = 1.045
        } else if statistics.standardDeviation < 0.21 {
            multiplier = 1.03
        } else {
            multiplier = 1.015
        }

        if toneCompression > 0.24 {
            multiplier = max(multiplier, 1.025)
        }

        if statistics.standardDeviation > 0.30,
           toneCompression < 0.18 {
            multiplier = 1
        }

        return multiplier
    }

    private func makeBlacksAdjustment(
        from statistics: LuminanceStatistics,
        shadowsAdjustment: Float
    ) -> Float {
        guard shadowsAdjustment > 0 else {
            if statistics.standardDeviation < 0.15,
               statistics.clippedShadowsShare < 0.02 {
                return -0.025
            }

            return 0
        }

        var adjustment = -(0.02 + shadowsAdjustment * 0.15)

        if statistics.clippedShadowsShare > 0.05 {
            adjustment *= 0.45
        }

        return clamped(adjustment, lower: -0.08, upper: 0)
    }

    private func makeWhitesAdjustment(
        from statistics: LuminanceStatistics,
        highlightsAdjustment: Float
    ) -> Float {
        guard highlightsAdjustment == 0 else {
            return 0
        }

        guard statistics.clippedHighlightsShare < 0.01 else {
            return 0
        }

        guard statistics.percentile99 < 0.97 else {
            return 0
        }

        if statistics.standardDeviation < 0.18 {
            return 0.035
        }

        if statistics.standardDeviation < 0.22 {
            return 0.02
        }

        return 0
    }

    private func makeVibranceAdjustment(from statistics: LuminanceStatistics) -> Float {
        if statistics.isLowKey || statistics.isHighKey {
            return 0.06
        }

        if statistics.standardDeviation < 0.16 {
            return 0.12
        }

        return 0.09
    }

    private func makeSharpenAdjustment(from statistics: LuminanceStatistics) -> Float {
        statistics.isLowKey ? 0.12 : 0.22
    }

    private func makeLuminanceHistogram(for image: CIImage) -> [Float]? {
        guard !image.extent.isEmpty, !image.extent.isInfinite else {
            return nil
        }

        let analysisImage = resizedForAnalysis(image)

        let grayscaleFilter = CIFilter.colorControls()
        grayscaleFilter.inputImage = analysisImage
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
        let rowBytes = histogramBinCount * componentsPerPixel * bytesPerComponent

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

        let histogram = stride(
            from: 0,
            to: bitmap.count,
            by: componentsPerPixel
        ).map {
            max(bitmap[$0], 0)
        }

        let total = histogram.reduce(0, +)

        guard total > 0, total.isFinite else {
            return nil
        }

        return histogram.map {
            $0 / total
        }
    }

    private func resizedForAnalysis(_ image: CIImage) -> CIImage {
        let maximumDimension = max(
            image.extent.width,
            image.extent.height
        )

        guard maximumDimension > analysisMaxPixelSize else {
            return image
        }

        let scale = analysisMaxPixelSize / maximumDimension

        return image.transformed(
            by: CGAffineTransform(
                scaleX: scale,
                y: scale
            )
        )
    }

    private func makeStatistics(from histogram: [Float]) -> LuminanceStatistics? {
        guard histogram.count == histogramBinCount else {
            return nil
        }

        let mean = histogram.enumerated().reduce(Float.zero) { result, item in
            let luminance = Float(item.offset) / Float(histogramBinCount - 1)
            return result + luminance * item.element
        }

        let variance = histogram.enumerated().reduce(Float.zero) { result, item in
            let luminance = Float(item.offset) / Float(histogramBinCount - 1)
            let difference = luminance - mean

            return result + difference * difference * item.element
        }

        return LuminanceStatistics(
            mean: mean,
            standardDeviation: sqrt(max(variance, 0)),
            percentile10: percentile(0.10, in: histogram),
            median: percentile(0.50, in: histogram),
            percentile90: percentile(0.90, in: histogram),
            percentile95: percentile(0.95, in: histogram),
            percentile99: percentile(0.99, in: histogram),
            clippedShadowsShare: share(below: 0.02, in: histogram),
            shadowsShare: share(below: 0.20, in: histogram),
            highlightsShare: share(above: 0.80, in: histogram),
            nearWhiteShare: share(above: 0.94, in: histogram),
            clippedHighlightsShare: share(above: 0.985, in: histogram)
        )
    }

    private func percentile(_ percentile: Float, in histogram: [Float]) -> Float {
        let target = clamped(percentile, lower: 0, upper: 1)
        var cumulativeShare: Float = 0

        for (index, share) in histogram.enumerated() {
            cumulativeShare += share

            if cumulativeShare >= target {
                return Float(index) / Float(histogramBinCount - 1)
            }
        }

        return 1
    }

    private func share(below threshold: Float, in histogram: [Float]) -> Float {
        histogram.enumerated().reduce(Float.zero) { result, item in
            let luminance = Float(item.offset) / Float(histogramBinCount - 1)

            guard luminance <= threshold else {
                return result
            }

            return result + item.element
        }
    }

    private func share(above threshold: Float, in histogram: [Float]) -> Float {
        histogram.enumerated().reduce(Float.zero) { result, item in
            let luminance = Float(item.offset) / Float(histogramBinCount - 1)

            guard luminance >= threshold else {
                return result
            }

            return result + item.element
        }
    }

    private func makeFallbackRecipe(from baseRecipe: EditRecipe) -> EditRecipe {
        var recipe = baseRecipe

        recipe.contrast = clamped(
            baseRecipe.contrast * 1.015,
            lower: 0.5,
            upper: 2
        )

        recipe.vibrance = clamped(
            baseRecipe.vibrance + 0.08,
            lower: -1,
            upper: 1
        )

        recipe.sharpen = max(
            baseRecipe.sharpen,
            0.15
        )

        return recipe
    }

    private func normalized(_ value: Float, maximum: Float) -> Float {
        guard maximum > 0 else {
            return 0
        }

        return clamped(
            value / maximum,
            lower: 0,
            upper: 1
        )
    }

    private func clamped(_ value: Float, lower: Float, upper: Float) -> Float {
        max(lower, min(value, upper))
    }
}
