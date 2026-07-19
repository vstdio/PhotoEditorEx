//
//  EditablePhoto.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 19.07.2026.
//

import UIKit

struct EditablePhoto: Identifiable {
    let id = UUID()
    let originalImage: UIImage
    var recipe: EditRecipe = .neutral
    var recipeBeforeAuto: EditRecipe?
}
