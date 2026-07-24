//
//  PhotoCollection.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 20.07.2026.
//

import Foundation

struct PhotoCollection: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var photos: [PhotoCollectionPhoto]
}

struct PhotoCollectionPhoto: Codable, Identifiable {
    let id: UUID
    let fileName: String
    var recipe: EditRecipe
    var recipeBeforeAuto: EditRecipe?
    var selectedPresetID: String? = nil
}
