//
//  PhotoCollectionStorageService.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 20.07.2026.
//

import UIKit
import UniformTypeIdentifiers

enum PhotoCollectionStorageError: LocalizedError {

    case storageDirectoryUnavailable
    case invalidImportedImage
    case collectionNotFound
    case missingImageFile
    case noPhotosImported

    var errorDescription: String? {
        switch self {
        case .storageDirectoryUnavailable:
            return "Не удалось открыть хранилище коллекций."

        case .invalidImportedImage:
            return "Не удалось импортировать выбранное изображение."

        case .collectionNotFound:
            return "Коллекция не найдена."

        case .missingImageFile:
            return "Один из файлов коллекции отсутствует."

        case .noPhotosImported:
            return "Не удалось импортировать выбранные фотографии."
        }
    }
}

final class PhotoCollectionStorageService {

    private let fileManager: FileManager
    private let rootURL: URL

    private let queue = DispatchQueue(
        label: "PhotoLab.collection-storage",
        qos: .userInitiated
    )

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        guard let applicationSupportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            fatalError("Application Support directory is unavailable")
        }

        var rootURL = applicationSupportURL.appendingPathComponent(
            "PhotoCollections",
            isDirectory: true
        )

        try? fileManager.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? rootURL.setResourceValues(resourceValues)

        self.rootURL = rootURL
    }

    func createCollection() async throws -> PhotoCollection {
        try await perform { [self] in
            let now = Date()

            let collection = PhotoCollection(
                id: UUID(),
                createdAt: now,
                updatedAt: now,
                photos: []
            )

            try createDirectories(for: collection.id)
            try saveSync(collection)

            return collection
        }
    }

    /// Вызывается прямо внутри callback loadFileRepresentation.
    /// Временный URL необходимо скопировать до выхода из callback.
    func copyImportedPhoto(
        from temporaryURL: URL,
        typeIdentifier: String,
        collectionID: UUID
    ) throws -> EditablePhoto {
        try createDirectories(for: collectionID)

        let photoID = UUID()

        let fileExtension: String

        if !temporaryURL.pathExtension.isEmpty {
            fileExtension = temporaryURL.pathExtension.lowercased()
        } else {
            fileExtension = UTType(typeIdentifier)?.preferredFilenameExtension ?? "jpg"
        }

        let fileName = "\(photoID.uuidString).\(fileExtension)"
        let destinationURL = originalsURL(for: collectionID)
            .appendingPathComponent(fileName)

        try fileManager.copyItem(
            at: temporaryURL,
            to: destinationURL
        )

        guard let image = UIImage(contentsOfFile: destinationURL.path) else {
            try? fileManager.removeItem(at: destinationURL)
            throw PhotoCollectionStorageError.invalidImportedImage
        }

        return EditablePhoto(
            id: photoID,
            originalFileURL: destinationURL,
            originalImage: image
        )
    }

    func save(_ collection: PhotoCollection) async throws {
        try await perform { [self] in
            try saveSync(collection)
        }
    }

    func updateCollection(id: UUID, photos: [PhotoCollectionPhoto]) async throws {
        try await perform { [self] in
            var collection = try loadCollectionSync(id: id)
            collection.photos = photos
            collection.updatedAt = Date()
            try saveSync(collection)
        }
    }

    func loadCollections() async throws -> [PhotoCollection] {
        try await perform { [self] in
            let directoryURLs = try fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            let collections = directoryURLs.compactMap { directoryURL -> PhotoCollection? in
                guard let id = UUID(uuidString: directoryURL.lastPathComponent) else {
                    return nil
                }

                return try? loadCollectionSync(id: id)
            }

            return collections.sorted {
                $0.updatedAt > $1.updatedAt
            }
        }
    }

    func loadEditablePhotos(for collection: PhotoCollection) async throws -> [EditablePhoto] {
        try await perform { [self] in
            try collection.photos.map { storedPhoto in
                let fileURL = originalsURL(for: collection.id)
                    .appendingPathComponent(storedPhoto.fileName)

                guard let image = UIImage(contentsOfFile: fileURL.path) else {
                    throw PhotoCollectionStorageError.missingImageFile
                }

                let preset = PhotoPreset(rawValue: storedPhoto.selectedPresetID ?? "") ?? .none

                return EditablePhoto(
                    id: storedPhoto.id,
                    originalFileURL: fileURL,
                    originalImage: image,
                    recipe: storedPhoto.recipe,
                    recipeBeforeAuto: storedPhoto.recipeBeforeAuto,
                    preset: preset
                )
            }
        }
    }

    func loadCoverImage(for collection: PhotoCollection) async throws -> UIImage? {
        try await perform { [self] in
            guard let firstPhoto = collection.photos.first else {
                return nil
            }

            let fileURL = originalsURL(for: collection.id)
                .appendingPathComponent(firstPhoto.fileName)

            guard let image = UIImage(contentsOfFile: fileURL.path) else {
                return nil
            }

            return image.resizedForEditorPreview(maxPixelSize: 240)
        }
    }

    func deleteCollection(id: UUID) async throws {
        try await perform { [self] in
            let directoryURL = collectionURL(for: id)

            guard fileManager.fileExists(atPath: directoryURL.path) else {
                return
            }

            try fileManager.removeItem(at: directoryURL)
        }
    }

    private func saveSync(_ collection: PhotoCollection) throws {
        try createDirectories(for: collection.id)

        let data = try encoder.encode(collection)

        try data.write(
            to: manifestURL(for: collection.id),
            options: .atomic
        )
    }

    private func loadCollectionSync(id: UUID) throws -> PhotoCollection {
        let manifestURL = manifestURL(for: id)

        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw PhotoCollectionStorageError.collectionNotFound
        }

        let data = try Data(contentsOf: manifestURL)
        return try decoder.decode(PhotoCollection.self, from: data)
    }

    private func createDirectories(for collectionID: UUID) throws {
        try fileManager.createDirectory(
            at: originalsURL(for: collectionID),
            withIntermediateDirectories: true
        )
    }

    private func collectionURL(for id: UUID) -> URL {
        rootURL.appendingPathComponent(
            id.uuidString,
            isDirectory: true
        )
    }

    private func originalsURL(for id: UUID) -> URL {
        collectionURL(for: id).appendingPathComponent(
            "originals",
            isDirectory: true
        )
    }

    private func manifestURL(for id: UUID) -> URL {
        collectionURL(for: id).appendingPathComponent("collection.json")
    }

    private func perform<T>(_ operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
