//
//  PhotoMetadata.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 24.07.2026.
//

import Foundation

struct PhotoMetadata {
    let sections: [Section]

    struct Section {
        let title: String
        let rows: [Row]
    }

    struct Row {
        let title: String
        let value: String
    }
}
