//
//  EditRecipe.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 16.07.2026.
//

import Foundation

struct EditRecipe: Equatable {

    static let neutral = EditRecipe()

    var brightness: Float = 0
    var contrast: Float = 1
    var saturation: Float = 1
    var exposure: Float = 0

    var shadows: Float = 0
    var highlights: Float = 0
    var whites: Float = 0
    var blacks: Float = 0

    var blurRadius: Float = 0
    var sharpen: Float = 0
    var vignette: Float = 0

    var isNeutral: Bool {
        self == .neutral
    }
}
