//
//  PhotoExportService.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 16.07.2026.
//

import UIKit
import Photos

enum PhotoExportError: LocalizedError {

    case renderFailed
    case jpegDataCreationFailed
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Не удалось обработать изображение."

        case .jpegDataCreationFailed:
            return "Не удалось создать JPEG-файл."

        case .accessDenied:
            return "Нет доступа для сохранения фото в галерею."
        }
    }
}

final class PhotoExportService {

    func requestAddOnlyAccess() async throws {
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }

        switch status {
        case .authorized, .limited:
            return

        case .denied, .restricted, .notDetermined:
            throw PhotoExportError.accessDenied

        @unknown default:
            throw PhotoExportError.accessDenied
        }
    }

    func saveToPhotoLibrary(
        image: UIImage,
        compressionQuality: CGFloat = 0.95
    ) async throws {
        guard let jpegData = image.jpegData(
            compressionQuality: compressionQuality
        ) else {
            throw PhotoExportError.jpegDataCreationFailed
        }

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()

                request.addResource(
                    with: .photo,
                    data: jpegData,
                    options: nil
                )
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: PhotoExportError.jpegDataCreationFailed
                    )
                }
            }
        }
    }
}
