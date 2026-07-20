//
//  PhotoPreset.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 20.07.2026.
//

import Foundation

enum PhotoPreset: String, Codable, CaseIterable, Identifiable {

    case none
    case vivid
    case warmFilm
    case sepia
    case blackAndWhite

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .none:
            return "None"

        case .vivid:
            return "Vivid"

        case .warmFilm:
            return "Warm Film"

        case .sepia:
            return "Sepia"

        case .blackAndWhite:
            return "B&W"
        }
    }

    func applying(to baseRecipe: EditRecipe) -> EditRecipe {
        var recipe = baseRecipe

        switch self {
        case .none:
            break

        case .vivid:
            recipe.contrast = clamped(recipe.contrast * 1.06, lower: 0.5, upper: 2)
            recipe.vibrance = clamped(recipe.vibrance + 0.18, lower: -1, upper: 1)
            recipe.saturation = clamped(recipe.saturation * 1.06, lower: 0, upper: 2)
            recipe.whites = clamped(recipe.whites + 0.04, lower: -1, upper: 1)
            recipe.blacks = clamped(recipe.blacks - 0.03, lower: -1, upper: 1)
            recipe.vignette = max(recipe.vignette, 0.18)

        case .warmFilm:
            recipe.contrast = clamped(recipe.contrast * 0.98, lower: 0.5, upper: 2)
            recipe.temperature = clamped(recipe.temperature + 0.16, lower: -1, upper: 1)
            recipe.tint = clamped(recipe.tint + 0.025, lower: -1, upper: 1)
            recipe.saturation = clamped(recipe.saturation * 0.96, lower: 0, upper: 2)
            recipe.vibrance = clamped(recipe.vibrance + 0.08, lower: -1, upper: 1)
            recipe.blacks = clamped(recipe.blacks + 0.035, lower: -1, upper: 1)
            recipe.highlights = clamped(recipe.highlights - 0.05, lower: -1, upper: 1)
            recipe.vignette = max(recipe.vignette, 0.14)

        case .sepia:
            recipe.contrast = clamped(recipe.contrast * 1.04, lower: 0.5, upper: 2)
            recipe.temperature = clamped(recipe.temperature + 0.32, lower: -1, upper: 1)
            recipe.tint = clamped(recipe.tint + 0.08, lower: -1, upper: 1)
            recipe.saturation = clamped(recipe.saturation * 0.42, lower: 0, upper: 2)
            recipe.vibrance = clamped(recipe.vibrance - 0.08, lower: -1, upper: 1)
            recipe.blacks = clamped(recipe.blacks - 0.025, lower: -1, upper: 1)
            recipe.vignette = max(recipe.vignette, 0.28)

        case .blackAndWhite:
            recipe.saturation = 0
            recipe.vibrance = 0
            recipe.contrast = clamped(recipe.contrast * 1.10, lower: 0.5, upper: 2)
            recipe.blacks = clamped(recipe.blacks - 0.06, lower: -1, upper: 1)
            recipe.whites = clamped(recipe.whites + 0.035, lower: -1, upper: 1)
            recipe.vignette = max(recipe.vignette, 0.20)
        }

        return recipe
    }

    private func clamped(_ value: Float, lower: Float, upper: Float) -> Float {
        max(lower, min(value, upper))
    }
}
