//
//  PhotoMetadataService.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 24.07.2026.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoMetadataError: LocalizedError {
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "Не удалось прочитать данные фотографии."
        }
    }
}

final class PhotoMetadataService {

    private let queue = DispatchQueue(
        label: "PhotoLab.photo-metadata",
        qos: .userInitiated
    )

    func loadMetadata(from fileURL: URL) async throws -> PhotoMetadata {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    let metadata = try makeMetadata(from: fileURL)
                    continuation.resume(returning: metadata)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func makeMetadata(from fileURL: URL) throws -> PhotoMetadata {
        let options = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithURL(
            fileURL as CFURL,
            options
        ) else {
            throw PhotoMetadataError.unreadableFile
        }

        guard let rawProperties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            nil
        ) else {
            throw PhotoMetadataError.unreadableFile
        }

        let properties = rawProperties as NSDictionary

        let tiff = dictionary(
            in: properties,
            key: kCGImagePropertyTIFFDictionary
        )

        let exif = dictionary(
            in: properties,
            key: kCGImagePropertyExifDictionary
        )

        var sections: [PhotoMetadata.Section] = []

        let fileRows = makeFileRows(
            source: source,
            properties: properties,
            fileURL: fileURL
        )

        if !fileRows.isEmpty {
            sections.append(PhotoMetadata.Section(
                title: "File",
                rows: fileRows
            ))
        }

        let captureRows = makeCaptureRows(
            tiff: tiff,
            exif: exif
        )

        if !captureRows.isEmpty {
            sections.append(PhotoMetadata.Section(
                title: "Capture",
                rows: captureRows
            ))
        }

        let exposureRows = makeExposureRows(exif: exif)

        if !exposureRows.isEmpty {
            sections.append(PhotoMetadata.Section(
                title: "Exposure",
                rows: exposureRows
            ))
        }

        let imageRows = makeImageRows(properties: properties)

        if !imageRows.isEmpty {
            sections.append(PhotoMetadata.Section(
                title: "Image",
                rows: imageRows
            ))
        }

        return PhotoMetadata(sections: sections)
    }

    private func makeFileRows(
        source: CGImageSource,
        properties: NSDictionary,
        fileURL: URL
    ) -> [PhotoMetadata.Row] {
        var rows: [PhotoMetadata.Row] = []

        rows.append(PhotoMetadata.Row(
            title: "Format",
            value: formatName(
                for: source,
                fileURL: fileURL
            )
        ))

        if let width = number(
            in: properties,
            key: kCGImagePropertyPixelWidth
        ),
           let height = number(
            in: properties,
            key: kCGImagePropertyPixelHeight
           ) {
            rows.append(PhotoMetadata.Row(
                title: "Dimensions",
                value: "\(Int(width.rounded())) × \(Int(height.rounded()))"
            ))
        }

        let resourceValues = try? fileURL.resourceValues(
            forKeys: [.fileSizeKey]
        )

        if let fileSize = resourceValues?.fileSize {
            rows.append(PhotoMetadata.Row(
                title: "File size",
                value: ByteCountFormatter.string(
                    fromByteCount: Int64(fileSize),
                    countStyle: .file
                )
            ))
        }

        return rows
    }

    private func makeCaptureRows(
        tiff: NSDictionary?,
        exif: NSDictionary?
    ) -> [PhotoMetadata.Row] {
        var rows: [PhotoMetadata.Row] = []

        let make = string(
            in: tiff,
            key: kCGImagePropertyTIFFMake
        )

        let model = string(
            in: tiff,
            key: kCGImagePropertyTIFFModel
        )

        if let camera = cameraName(
            make: make,
            model: model
        ) {
            rows.append(PhotoMetadata.Row(
                title: "Camera",
                value: camera
            ))
        }

        if let lens = string(
            in: exif,
            key: kCGImagePropertyExifLensModel
        ) {
            rows.append(PhotoMetadata.Row(
                title: "Lens",
                value: lens
            ))
        }

        let rawDate = string(
            in: exif,
            key: kCGImagePropertyExifDateTimeOriginal
        ) ?? string(
            in: tiff,
            key: kCGImagePropertyTIFFDateTime
        )

        if let rawDate {
            rows.append(PhotoMetadata.Row(
                title: "Date taken",
                value: formattedDate(rawDate)
            ))
        }

        if let software = string(
            in: tiff,
            key: kCGImagePropertyTIFFSoftware
        ) {
            rows.append(PhotoMetadata.Row(
                title: "Software",
                value: software
            ))
        }

        return rows
    }

    private func makeExposureRows(
        exif: NSDictionary?
    ) -> [PhotoMetadata.Row] {
        var rows: [PhotoMetadata.Row] = []

        if let focalLength = number(
            in: exif,
            key: kCGImagePropertyExifFocalLength
        ) {
            rows.append(PhotoMetadata.Row(
                title: "Focal length",
                value: "\(formattedNumber(focalLength, maximumFractionDigits: 1)) mm"
            ))
        }

        if let aperture = number(
            in: exif,
            key: kCGImagePropertyExifFNumber
        ) {
            rows.append(PhotoMetadata.Row(
                title: "Aperture",
                value: "f/\(formattedNumber(aperture, maximumFractionDigits: 1))"
            ))
        }

        if let exposureTime = number(
            in: exif,
            key: kCGImagePropertyExifExposureTime
        ),
           let formattedExposureTime = formattedExposureTime(
            exposureTime
           ) {
            rows.append(PhotoMetadata.Row(
                title: "Shutter speed",
                value: formattedExposureTime
            ))
        }

        if let iso = isoValue(in: exif) {
            rows.append(PhotoMetadata.Row(
                title: "ISO",
                value: String(iso)
            ))
        }

        if let exposureBias = number(
            in: exif,
            key: kCGImagePropertyExifExposureBiasValue
        ) {
            let sign = exposureBias > 0 ? "+" : ""

            rows.append(PhotoMetadata.Row(
                title: "Exposure compensation",
                value: "\(sign)\(formattedNumber(exposureBias, maximumFractionDigits: 2)) EV"
            ))
        }

        return rows
    }

    private func makeImageRows(
        properties: NSDictionary
    ) -> [PhotoMetadata.Row] {
        var rows: [PhotoMetadata.Row] = []

        if let colorModel = string(
            in: properties,
            key: kCGImagePropertyColorModel
        ) {
            rows.append(PhotoMetadata.Row(
                title: "Color model",
                value: colorModel
            ))
        }

        if let profileName = string(
            in: properties,
            key: kCGImagePropertyProfileName
        ) {
            rows.append(PhotoMetadata.Row(
                title: "Color profile",
                value: profileName
            ))
        }

        if let depth = number(
            in: properties,
            key: kCGImagePropertyDepth
        ) {
            rows.append(PhotoMetadata.Row(
                title: "Bit depth",
                value: "\(Int(depth.rounded())) bit"
            ))
        }

        return rows
    }

    private func dictionary(
        in dictionary: NSDictionary,
        key: CFString
    ) -> NSDictionary? {
        dictionary.object(forKey: key) as? NSDictionary
    }

    private func string(
        in dictionary: NSDictionary?,
        key: CFString
    ) -> String? {
        dictionary?.object(forKey: key) as? String
    }

    private func number(
        in dictionary: NSDictionary?,
        key: CFString
    ) -> Double? {
        let number = dictionary?.object(forKey: key) as? NSNumber
        return number?.doubleValue
    }

    private func isoValue(
        in exif: NSDictionary?
    ) -> Int? {
        guard let rawValue = exif?.object(
            forKey: kCGImagePropertyExifISOSpeedRatings
        ) else {
            return nil
        }

        if let number = rawValue as? NSNumber {
            return number.intValue
        }

        if let values = rawValue as? [NSNumber],
           let firstValue = values.first {
            return firstValue.intValue
        }

        return nil
    }

    private func formatName(
        for source: CGImageSource,
        fileURL: URL
    ) -> String {
        if let typeIdentifier = CGImageSourceGetType(source) as String?,
           let type = UTType(typeIdentifier),
           let fileExtension = type.preferredFilenameExtension {
            return fileExtension.uppercased()
        }

        let fileExtension = fileURL.pathExtension.uppercased()

        return fileExtension.isEmpty
            ? "Unknown"
            : fileExtension
    }

    private func cameraName(
        make: String?,
        model: String?
    ) -> String? {
        let make = make?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let model = model?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        switch (make, model) {
        case let (make?, model?):
            if model.localizedCaseInsensitiveContains(make) {
                return model
            }

            return "\(make) \(model)"

        case let (make?, nil):
            return make

        case let (nil, model?):
            return model

        case (nil, nil):
            return nil
        }
    }

    private func formattedExposureTime(
        _ exposureTime: Double
    ) -> String? {
        guard exposureTime > 0 else {
            return nil
        }

        if exposureTime < 0.25 {
            let denominator = max(
                Int((1 / exposureTime).rounded()),
                1
            )

            return "1/\(denominator) s"
        }

        return "\(formattedNumber(exposureTime, maximumFractionDigits: 3)) s"
    }

    private func formattedDate(
        _ rawDate: String
    ) -> String {
        let inputFormatter = DateFormatter()

        inputFormatter.locale = Locale(
            identifier: "en_US_POSIX"
        )

        inputFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"

        guard let date = inputFormatter.date(
            from: rawDate
        ) else {
            return rawDate
        }

        let outputFormatter = DateFormatter()

        outputFormatter.locale = .current
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .medium

        return outputFormatter.string(from: date)
    }

    private func formattedNumber(
        _ value: Double,
        maximumFractionDigits: Int
    ) -> String {
        let formatter = NumberFormatter()

        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits

        return formatter.string(
            from: NSNumber(value: value)
        ) ?? String(value)
    }
}
