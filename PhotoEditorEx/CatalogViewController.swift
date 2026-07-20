//
//  CatalogViewController.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 01.07.2026.
//

import UIKit
import PhotosUI
import UniformTypeIdentifiers
import SnapKit

final class CatalogViewController: UIViewController {

    private let storageService = PhotoCollectionStorageService()

    private var collections: [PhotoCollection] = []
    private var coverImages: [UUID: UIImage] = [:]
    private var catalogLoadTask: Task<Void, Never>?

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "Здесь появятся коллекции фотографий.\nНажми +, чтобы импортировать первую."
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.rowHeight = 76
        return tableView
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Catalog"
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        setupLayout()

        tableView.register(
            PhotoCollectionCell.self,
            forCellReuseIdentifier: PhotoCollectionCell.reuseIdentifier
        )

        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reloadCatalog()
    }

    deinit {
        catalogLoadTask?.cancel()
    }

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .add,
            primaryAction: UIAction { [weak self] _ in
                self?.showPhotoPicker()
            }
        )
    }

    private func setupLayout() {
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        view.addSubview(activityIndicator)

        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        emptyStateLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(32)
            make.centerY.equalToSuperview()
        }

        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func showPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 20
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self

        present(picker, animated: true)
    }

    private func reloadCatalog() {
        catalogLoadTask?.cancel()

        catalogLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            setLoading(true)
            defer { setLoading(false) }

            do {
                let loadedCollections = try await storageService.loadCollections()
                var loadedCovers: [UUID: UIImage] = [:]

                for collection in loadedCollections {
                    guard !Task.isCancelled else { return }

                    loadedCovers[collection.id] = try await storageService.loadCoverImage(
                        for: collection
                    )
                }

                collections = loadedCollections
                coverImages = loadedCovers

                tableView.reloadData()
                updateCatalogState()
            } catch {
                showError(message: error.localizedDescription)
            }
        }
    }

    private func updateCatalogState() {
        let isEmpty = collections.isEmpty

        emptyStateLabel.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }

    private func importCollection(from results: [PHPickerResult]) {
        setLoading(true)

        Task { @MainActor [weak self] in
            guard let self else { return }

            var createdCollection: PhotoCollection?

            do {
                var collection = try await storageService.createCollection()
                createdCollection = collection

                var editablePhotos: [EditablePhoto] = []

                for result in results {
                    guard let photo = try await importPhoto(
                        from: result,
                        collectionID: collection.id
                    ) else {
                        continue
                    }

                    editablePhotos.append(photo)
                }

                guard !editablePhotos.isEmpty else {
                    throw PhotoCollectionStorageError.noPhotosImported
                }

                collection.photos = editablePhotos.map(\.storedPhoto)
                collection.updatedAt = Date()

                try await storageService.save(collection)

                setLoading(false)

                let editorViewController = EditorViewController(
                    collectionID: collection.id,
                    photos: editablePhotos,
                    storageService: storageService
                )

                navigationController?.pushViewController(
                    editorViewController,
                    animated: true
                )
            } catch {
                if let createdCollection {
                    try? await storageService.deleteCollection(id: createdCollection.id)
                }

                setLoading(false)
                showError(message: error.localizedDescription)
            }
        }
    }

    private func importPhoto(
        from result: PHPickerResult,
        collectionID: UUID
    ) async throws -> EditablePhoto? {
        let provider = result.itemProvider

        guard let typeIdentifier = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .image) == true
        }) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) {
                [storageService] temporaryURL, error in

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let temporaryURL else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let photo = try storageService.copyImportedPhoto(
                        from: temporaryURL,
                        typeIdentifier: typeIdentifier,
                        collectionID: collectionID
                    )

                    continuation.resume(returning: photo)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func openCollection(_ collection: PhotoCollection) {
        setLoading(true)

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let photos = try await storageService.loadEditablePhotos(
                    for: collection
                )

                guard !photos.isEmpty else {
                    throw PhotoCollectionStorageError.noPhotosImported
                }

                setLoading(false)

                let editorViewController = EditorViewController(
                    collectionID: collection.id,
                    photos: photos,
                    storageService: storageService
                )

                navigationController?.pushViewController(
                    editorViewController,
                    animated: true
                )
            } catch {
                setLoading(false)
                showError(message: error.localizedDescription)
            }
        }
    }

    private func confirmCollectionDeletion(
        at indexPath: IndexPath,
        completion: @escaping (Bool) -> Void
    ) {
        guard collections.indices.contains(indexPath.row) else {
            completion(false)
            return
        }

        let collection = collections[indexPath.row]

        let alert = UIAlertController(
            title: "Удалить коллекцию?",
            message: "Коллекция и сохраненные оригиналы будут удалены без возможности восстановления.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel) { _ in
            completion(false)
        })

        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.deleteCollection(collection, at: indexPath, completion: completion)
        })

        present(alert, animated: true)
    }

    private func deleteCollection(
        _ collection: PhotoCollection,
        at indexPath: IndexPath,
        completion: @escaping (Bool) -> Void
    ) {
        setLoading(true)

        Task { @MainActor [weak self] in
            guard let self else {
                completion(false)
                return
            }

            do {
                try await storageService.deleteCollection(id: collection.id)

                guard let currentIndex = collections.firstIndex(where: { $0.id == collection.id }) else {
                    setLoading(false)
                    completion(false)
                    return
                }

                collections.remove(at: currentIndex)
                coverImages.removeValue(forKey: collection.id)

                let currentIndexPath = IndexPath(row: currentIndex, section: 0)

                tableView.deleteRows(at: [currentIndexPath], with: .automatic)
                updateCatalogState()
                setLoading(false)

                completion(true)
            } catch {
                setLoading(false)
                completion(false)
                showError(message: error.localizedDescription)
            }
        }
    }

    private func setLoading(_ isLoading: Bool) {
        tableView.isUserInteractionEnabled = !isLoading
        navigationItem.rightBarButtonItem?.isEnabled = !isLoading

        if isLoading {
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

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension CatalogViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard !results.isEmpty else { return }

        importCollection(from: results)
    }
}

extension CatalogViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        collections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: PhotoCollectionCell.reuseIdentifier,
            for: indexPath
        ) as? PhotoCollectionCell else {
            return UITableViewCell()
        }

        let collection = collections[indexPath.row]

        cell.configure(
            image: coverImages[collection.id] ?? UIImage(systemName: "photo.stack"),
            title: Self.dateFormatter.string(from: collection.createdAt),
            subtitle: "\(collection.photos.count) photos"
        )

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openCollection(collections[indexPath.row])
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") {
            [weak self] _, _, completion in

            self?.confirmCollectionDeletion(at: indexPath, completion: completion)
        }

        deleteAction.image = UIImage(systemName: "trash")

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = false

        return configuration
    }
}

private final class PhotoCollectionCell: UITableViewCell {

    static let reuseIdentifier = "PhotoCollectionCell"

    private let thumbnailContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()

    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.tintColor = .secondaryLabel
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        accessoryType = .disclosureIndicator

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        thumbnailImageView.image = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
    }

    func configure(image: UIImage?, title: String, subtitle: String) {
        thumbnailImageView.image = image
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    private func setupLayout() {
        let labelsStackView = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel
        ])

        labelsStackView.axis = .vertical
        labelsStackView.spacing = 3

        contentView.addSubview(thumbnailContainerView)
        contentView.addSubview(labelsStackView)

        thumbnailContainerView.addSubview(thumbnailImageView)

        thumbnailContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(52)
        }

        thumbnailImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        labelsStackView.snp.makeConstraints { make in
            make.leading.equalTo(thumbnailContainerView.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualToSuperview().inset(8)
            make.centerY.equalToSuperview()
        }
    }
}
