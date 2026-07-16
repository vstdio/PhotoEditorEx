//
//  FilterRecipe.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 01.07.2026.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct EditRecipe {
    var brightness: Float = 0
    var contrast: Float = 1
    var saturation: Float = 1
    var exposure: Float = 0
    var blurRadius: Float = 0
    var sharpen: Float = 0
    var vignette: Float = 0
}

final class FilterPipeline {

    private let context = CIContext(options: [
        .cacheIntermediates: false
    ])

    func renderPreview(ciImage inputImage: CIImage, recipe: EditRecipe) -> UIImage? {
        render(ciImage: inputImage, recipe: recipe, scale: UIScreen.main.scale)
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

        outputImage = applyExposure(to: outputImage, recipe: recipe)
        outputImage = applyColorControls(to: outputImage, recipe: recipe)
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

    private func applyExposure(to image: CIImage, recipe: EditRecipe) -> CIImage {
        guard recipe.exposure != 0 else {
            return image
        }

        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        filter.ev = recipe.exposure

        return filter.outputImage ?? image
    }

    private func applyColorControls(to image: CIImage, recipe: EditRecipe) -> CIImage {
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
