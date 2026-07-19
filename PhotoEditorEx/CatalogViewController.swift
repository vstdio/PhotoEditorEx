//
//  CatalogViewController.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 01.07.2026.
//

import UIKit
import PhotosUI
import SnapKit

final class CatalogViewController: UIViewController {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "PhotoLab"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Импортируй фото и попробуй первую обработку"
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let importButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Import Photo", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.configuration = .filled()
        return button
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Catalog"
        view.backgroundColor = .systemBackground

        setupLayout()
        setupActions()
    }

    private func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            importButton,
            activityIndicator
        ])

        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .center

        view.addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.centerY.equalToSuperview()
        }

        importButton.snp.makeConstraints { make in
            make.height.equalTo(48)
            make.width.equalTo(180)
        }
    }

    private func setupActions() {
        importButton.addTarget(
            self,
            action: #selector(importButtonTapped),
            for: .touchUpInside
        )
    }

    @objc private func importButtonTapped() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 20
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self

        present(picker, animated: true)
    }
}

extension CatalogViewController: PHPickerViewControllerDelegate {

    func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }

        setImporting(true)

        Task { @MainActor [weak self] in
            guard let self else { return }
            let images = await loadImages(from: results)
            finishImport(images: images)
        }
    }

    private func loadImages(
        from results: [PHPickerResult]
    ) async -> [UIImage] {
        var images: [UIImage] = []

        for result in results {
            let provider = result.itemProvider
            guard let image = await loadImage(from: provider) else { continue }
            images.append(image)
        }

        return images
    }

    private func loadImage(
        from provider: NSItemProvider
    ) async -> UIImage? {
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(
                    returning: object as? UIImage
                )
            }
        }
    }

    private func finishImport(images: [UIImage]) {
        setImporting(false)

        guard !images.isEmpty else {
            showError(message: "Не удалось загрузить выбранные изображения.")
            return
        }

        let editorViewController = EditorViewController(
            photos: images.map { EditablePhoto(originalImage: $0) }
        )

        navigationController?.pushViewController(
            editorViewController,
            animated: true
        )
    }

    private func setImporting(_ isImporting: Bool) {
        importButton.isEnabled = !isImporting

        if isImporting {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    private func showError(message: String) {
        let alert = UIAlertController(
            title: "Ошибка",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: "OK",
                style: .default
            )
        )

        present(alert, animated: true)
    }
}
