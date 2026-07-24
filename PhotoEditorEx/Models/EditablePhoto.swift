//
//  EditablePhoto.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 19.07.2026.
//

import UIKit

struct EditablePhoto: Identifiable {
    let id: UUID
    let originalFileURL: URL
    let originalImage: UIImage
    var recipe: EditRecipe
    var recipeBeforeAuto: EditRecipe?
    var preset: PhotoPreset

    init(
        id: UUID = UUID(),
        originalFileURL: URL,
        originalImage: UIImage,
        recipe: EditRecipe = .neutral,
        recipeBeforeAuto: EditRecipe? = nil,
        preset: PhotoPreset = .none
    ) {
        self.id = id
        self.originalFileURL = originalFileURL
        self.originalImage = originalImage
        self.recipe = recipe
        self.recipeBeforeAuto = recipeBeforeAuto
        self.preset = preset
    }

    var storedPhoto: PhotoCollectionPhoto {
        PhotoCollectionPhoto(
            id: id,
            fileName: originalFileURL.lastPathComponent,
            recipe: recipe,
            recipeBeforeAuto: recipeBeforeAuto,
            selectedPresetID: preset == .none ? nil : preset.rawValue
        )
    }
}
