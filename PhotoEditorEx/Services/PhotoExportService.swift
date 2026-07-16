//
//  PhotoExportService.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 16.07.2026.
//

import UIKit
import Photos

enum PhotoExportError: LocalizedError {
    case jpegDataCreationFailed
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .jpegDataCreationFailed:
            return "Не удалось создать JPEG-файл."
        case .accessDenied:
            return "Нет доступа для сохранения фото в галерею."
        }
    }
}

final class PhotoExportService {

    func saveToPhotoLibrary(
        image: UIImage,
        compressionQuality: CGFloat = 0.95,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let jpegData = image.jpegData(compressionQuality: compressionQuality) else {
            completion(.failure(PhotoExportError.jpegDataCreationFailed))
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            switch status {
            case .authorized, .limited:
                PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: jpegData, options: nil)
                } completionHandler: { success, error in
                    DispatchQueue.main.async {
                        if let error {
                            completion(.failure(error))
                        } else if success {
                            completion(.success(()))
                        } else {
                            completion(.failure(PhotoExportError.jpegDataCreationFailed))
                        }
                    }
                }

            case .denied, .restricted, .notDetermined:
                DispatchQueue.main.async {
                    completion(.failure(PhotoExportError.accessDenied))
                }

            @unknown default:
                DispatchQueue.main.async {
                    completion(.failure(PhotoExportError.accessDenied))
                }
            }
        }
    }
}
