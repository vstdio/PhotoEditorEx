//
//  FilterPipeline.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 01.07.2026.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class FilterPipeline {

    private let context = CIContext(options: [
        .cacheIntermediates: false
    ])

    func renderPreview(ciImage inputImage: CIImage, recipe: EditRecipe) -> UIImage? {
        render(
            ciImage: inputImage,
            recipe: recipe,
            scale: UIScreen.main.scale
        )
    }

    func renderFullSize(image: UIImage, recipe: EditRecipe) -> UIImage? {
        let normalizedImage = image.normalized()

        guard let inputCIImage = CIImage(image: normalizedImage) else {
            return nil
        }

        return render(
            ciImage: inputCIImage,
            recipe: recipe,
            scale: normalizedImage.scale
        )
    }

    private func render(
        ciImage inputImage: CIImage,
        recipe: EditRecipe,
        scale: CGFloat
    ) -> UIImage? {
        let originalExtent = inputImage.extent

        var outputImage = inputImage

        outputImage = applyWhiteBalance(to: outputImage, recipe: recipe)
        outputImage = applyExposure(to: outputImage, recipe: recipe)
        outputImage = applyToneMapping(to: outputImage, recipe: recipe)
        outputImage = applyWhiteAndBlackPoints(to: outputImage, recipe: recipe)
        outputImage = applyColorControls(to: outputImage, recipe: recipe)
        outputImage = applyVibrance(to: outputImage, recipe: recipe)
        outputImage = applyBlur(to: outputImage, recipe: recipe, originalExtent: originalExtent)
        outputImage = applySharpen(to: outputImage, recipe: recipe)
        outputImage = applyVignette(to: outputImage, recipe: recipe)

        outputImage = outputImage.cropped(to: originalExtent)

        guard let cgImage = context.createCGImage(outputImage, from: originalExtent) else {
            return nil
        }

        return UIImage(
            cgImage: cgImage,
            scale: scale,
            orientation: .up
        )
    }

    private func applyWhiteBalance(
        to image: CIImage,
        recipe: EditRecipe
    ) -> CIImage {
        guard recipe.temperature != 0 || recipe.tint != 0 else {
            return image
        }

        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image

        filter.neutral = CIVector(
            x: 6500,
            y: 0
        )

        filter.targetNeutral = CIVector(
            x: 6500 - CGFloat(recipe.temperature) * 2500,
            y: CGFloat(recipe.tint) * 100
        )

        return filter.outputImage ?? image
    }

    private func applyVibrance(
        to image: CIImage,
        recipe: EditRecipe
    ) -> CIImage {
        guard recipe.vibrance != 0 else {
            return image
        }

        let filter = CIFilter.vibrance()
        filter.inputImage = image
        filter.amount = recipe.vibrance

        return filter.outputImage ?? image
    }

    private func applyExposure(to image: CIImage, recipe: EditRecipe) -> CIImage {
        guard recipe.exposure != 0 else {
            return image
        }

        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        filter.ev = recipe.exposure

        return filter.outputImage ?? image
    }

    private func applyToneMapping(
        to image: CIImage,
        recipe: EditRecipe
    ) -> CIImage {
        guard recipe.shadows != 0 || recipe.highlights != 0 else {
            return image
        }

        let filter = CIFilter.toneCurve()
        filter.inputImage = image

        filter.point0 = CGPoint(
            x: 0,
            y: 0
        )

        filter.point1 = CGPoint(
            x: 0.25,
            y: 0.25 + CGFloat(recipe.shadows) * 0.15
        )

        filter.point2 = CGPoint(
            x: 0.5,
            y: 0.5
        )

        filter.point3 = CGPoint(
            x: 0.75,
            y: 0.75 + CGFloat(recipe.highlights) * 0.15
        )

        filter.point4 = CGPoint(
            x: 1,
            y: 1
        )

        return filter.outputImage ?? image
    }

    private func applyWhiteAndBlackPoints(
        to image: CIImage,
        recipe: EditRecipe
    ) -> CIImage {
        guard recipe.whites != 0 || recipe.blacks != 0 else {
            return image
        }

        let blacks = CGFloat(recipe.blacks)
        let whites = CGFloat(recipe.whites)

        let filter = CIFilter.toneCurve()
        filter.inputImage = image

        filter.point0 = CGPoint(
            x: 0,
            y: max(blacks, 0) * 0.12
        )

        filter.point1 = CGPoint(
            x: 0.25,
            y: 0.25 + min(blacks, 0) * 0.12
        )

        filter.point2 = CGPoint(
            x: 0.5,
            y: 0.5
        )

        filter.point3 = CGPoint(
            x: 0.75,
            y: 0.75 + max(whites, 0) * 0.12
        )

        filter.point4 = CGPoint(
            x: 1,
            y: 1 + min(whites, 0) * 0.12
        )

        return filter.outputImage ?? image
    }

    private func applyColorControls(
        to image: CIImage,
        recipe: EditRecipe
    ) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = recipe.brightness
        filter.contrast = recipe.contrast
        filter.saturation = recipe.saturation
        return filter.outputImage ?? image
    }

    private func applyBlur(
        to image: CIImage,
        recipe: EditRecipe,
        originalExtent: CGRect
    ) -> CIImage {
        guard recipe.blurRadius > 0 else {
            return image
        }

        let filter = CIFilter.gaussianBlur()
        filter.inputImage = image.clampedToExtent()
        filter.radius = recipe.blurRadius

        return filter.outputImage?.cropped(to: originalExtent) ?? image
    }

    private func applySharpen(to image: CIImage, recipe: EditRecipe) -> CIImage {
        guard recipe.sharpen > 0 else {
            return image
        }

        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = image
        filter.sharpness = recipe.sharpen

        return filter.outputImage ?? image
    }

    private func applyVignette(to image: CIImage, recipe: EditRecipe) -> CIImage {
        guard recipe.vignette > 0 else {
            return image
        }

        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = recipe.vignette
        filter.radius = 1.5

        return filter.outputImage ?? image
    }
}
