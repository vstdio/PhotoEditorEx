//
//  UIImage+Preview.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 04.07.2026.
//

import UIKit

extension UIImage {

    func resizedForEditorPreview(maxPixelSize: CGFloat = 1600) -> UIImage {
        let width = size.width
        let height = size.height

        let largestSide = max(width, height)

        guard largestSide > maxPixelSize else {
            return normalized()
        }

        let scale = maxPixelSize / largestSide
        let newSize = CGSize(width: width * scale, height: height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func normalized() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
