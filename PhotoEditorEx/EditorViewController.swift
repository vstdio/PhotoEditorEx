//
//  EditorViewController.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 01.07.2026.
//

import UIKit
import CoreImage
import SnapKit

private enum EditorMode {
    case styles
    case adjustments
}

final class EditorViewController: UIViewController {

    private let collectionID: UUID
    private let collectionStorageService: PhotoCollectionStorageService
    private var collectionSaveTask: Task<Void, Never>?

    private var photos: [EditablePhoto]

    private var originalImage: UIImage
    private var previewImage: UIImage
    private var previewCIImage: CIImage

    private var currentPhotoIndex = 0
    private var photoSwitchRequestID: UUID?
    private var isApplyingPhotoState = false

    private var editorMode: EditorMode = .styles

    private var selectedPreset: PhotoPreset {
        didSet {
            guard oldValue != selectedPreset else { return }

            scheduleCollectionSave()
            scheduleRenderPreview()
        }
    }

    private let filterPipeline = FilterPipeline()
    private let renderQueue = DispatchQueue(
        label: "PhotoLab.editor.render",
        qos: .userInitiated
    )

    private let autoAdjustmentService = AutoAdjustmentService()
    private let autoQueue = DispatchQueue(
        label: "PhotoLab.editor.auto",
        qos: .userInitiated
    )

    private var autoRequestID: UUID?
    private var recipeBeforeAuto: EditRecipe?

    private var previewRenderRequest: PreviewRenderRequest?

    private let exportService = PhotoExportService()
    private let exportQueue = DispatchQueue(
        label: "PhotoLab.editor.export",
        qos: .userInitiated
    )
    private var isExporting = false
    private var isApplyingAutoToAll = false

    private let progressOverlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        view.layer.cornerRadius = 14
        view.isHidden = true
        return view
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private var recipe: EditRecipe = .neutral {
        didSet {
            guard photos.indices.contains(currentPhotoIndex) else { return }
            photos[currentPhotoIndex].recipe = recipe

            guard oldValue != recipe else { return }
            guard !isApplyingPhotoState else { return }

            scheduleCollectionSave()
            scheduleRenderPreview()
        }
    }

    private var renderedPreviewImage: UIImage?
    private var isShowingOriginal = false

    private let editorImageView = EditorImageView()
    private let editorImageContainerView = UIView()

    private let filmstripView = EditorFilmstripView()
    private let filmstripContainerView = UIView()

    private let presetPickerView = PresetPickerView()
    private let presetContainerView = UIView()

    private let actionBarView = EditorActionBarView()
    private let controlsView = EditorControlsView()

    private let actionBarContainerView = UIView()
    private let controlsContainerView = UIView()

    private let bottomPanelContainerView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 0
        stackView.backgroundColor = .systemBackground
        return stackView
    }()

    init(
        collectionID: UUID,
        photos: [EditablePhoto],
        selectedPreset: PhotoPreset,
        storageService: PhotoCollectionStorageService
    ) {
        guard let firstPhoto = photos.first else {
            fatalError("EditorViewController requires at least one photo")
        }

        self.collectionID = collectionID
        self.collectionStorageService = storageService
        self.photos = photos
        self.selectedPreset = selectedPreset
        self.originalImage = firstPhoto.originalImage

        let preview = firstPhoto.originalImage.resizedForEditorPreview(maxPixelSize: 1200)

        self.previewImage = preview
        self.previewCIImage = CIImage(image: preview) ?? CIImage()
        self.recipe = firstPhoto.recipe
        self.recipeBeforeAuto = firstPhoto.recipeBeforeAuto

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        previewRenderRequest?.cancel()
        collectionSaveTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateTitle()
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        setupLayout()
        setupActions()
        setupContainerAppearance()
        setEditorMode(.styles, animated: false)
        setupBeforeAfterGesture()

        presetPickerView.setSelectedPreset(selectedPreset, animated: false)
        filmstripView.configure(photos: photos, selectedIndex: currentPhotoIndex)
        controlsView.setRecipe(recipe, animated: false)
        actionBarView.setAutoEnabled(recipeBeforeAuto != nil)
        editorImageView.setImage(previewImage, resetZoom: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveCollectionImmediately()
    }

    private func updateTitle() {
        if photos.count == 1 {
            title = "Editor"
        } else {
            title = "\(currentPhotoIndex + 1) of \(photos.count)"
        }
    }

    private func setupBeforeAfterGesture() {
        let gestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleBeforeAfterGesture)
        )

        gestureRecognizer.minimumPressDuration = 0.15
        gestureRecognizer.allowableMovement = 8
        gestureRecognizer.cancelsTouchesInView = false

        editorImageView.addGestureRecognizer(gestureRecognizer)
    }

    private func setupNavigationBar() {
        let exportItem = UIBarButtonItem(
            title: "Export",
            image: nil,
            primaryAction: nil,
            menu: makeExportMenu()
        )

        let actionsItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            primaryAction: nil,
            menu: makeBatchActionsMenu()
        )

        navigationItem.rightBarButtonItems = [
            exportItem,
            actionsItem
        ]
    }

    private func makeExportMenu() -> UIMenu {
        let exportCurrentAction = UIAction(
            title: "Export Current",
            image: UIImage(systemName: "photo")
        ) { [weak self] _ in
            self?.exportCurrentPhoto()
        }

        let exportAllAttributes: UIMenuElement.Attributes = photos.count > 1
            ? []
            : [.disabled]

        let exportAllAction = UIAction(
            title: "Export All (\(photos.count))",
            image: UIImage(systemName: "photo.stack"),
            attributes: exportAllAttributes
        ) { [weak self] _ in
            self?.exportAllPhotos()
        }

        return UIMenu(
            title: "",
            children: [
                exportCurrentAction,
                exportAllAction
            ]
        )
    }

    private func makeBatchActionsMenu() -> UIMenu {
        let autoAllAttributes: UIMenuElement.Attributes = photos.count > 1
            ? []
            : [.disabled]

        let autoAllAction = UIAction(
            title: "Auto All (\(photos.count))",
            image: UIImage(systemName: "wand.and.stars"),
            attributes: autoAllAttributes
        ) { [weak self] _ in
            self?.applyAutoToAllPhotos()
        }

        return UIMenu(children: [
            autoAllAction
        ])
    }

    private func setupLayout() {
        view.addSubview(editorImageContainerView)
        view.addSubview(filmstripContainerView)
        view.addSubview(bottomPanelContainerView)
        view.addSubview(progressOverlayView)

        editorImageContainerView.addSubview(editorImageView)
        filmstripContainerView.addSubview(filmstripView)
        presetContainerView.addSubview(presetPickerView)
        actionBarContainerView.addSubview(actionBarView)
        controlsContainerView.addSubview(controlsView)

        bottomPanelContainerView.addArrangedSubview(presetContainerView)
        bottomPanelContainerView.addArrangedSubview(actionBarContainerView)
        bottomPanelContainerView.addArrangedSubview(controlsContainerView)

        bottomPanelContainerView.setCustomSpacing(6, after: presetContainerView)
        bottomPanelContainerView.setCustomSpacing(6, after: actionBarContainerView)

        progressOverlayView.addSubview(activityIndicator)
        progressOverlayView.addSubview(progressLabel)

        bottomPanelContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        presetContainerView.snp.makeConstraints { make in
            make.height.equalTo(66)
        }

        presetPickerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(4)
            make.leading.trailing.equalToSuperview().inset(12)
        }

        actionBarContainerView.snp.makeConstraints { make in
            make.height.equalTo(56)
        }

        actionBarView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(4)
            make.leading.trailing.equalToSuperview().inset(12)
        }

        controlsView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(4)
            make.leading.trailing.equalToSuperview().inset(12)
        }

        filmstripContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomPanelContainerView.snp.top)
            make.height.equalTo(photos.count > 1 ? 76 : 0)
        }

        filmstripView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(4)
            make.leading.trailing.equalToSuperview().inset(12)
        }

        editorImageContainerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(filmstripContainerView.snp.top).offset(-4)
        }

        editorImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        progressOverlayView.snp.makeConstraints { make in
            make.center.equalTo(editorImageView)
            make.width.greaterThanOrEqualTo(190)
            make.width.lessThanOrEqualToSuperview().inset(32)
        }

        activityIndicator.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.centerX.equalToSuperview()
        }

        progressLabel.snp.makeConstraints { make in
            make.top.equalTo(activityIndicator.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(20)
        }

        filmstripContainerView.isHidden = photos.count <= 1
    }

    private func setupActions() {
        actionBarView.onAutoTapped = { [weak self] isEnabled in
            self?.setAutoEnabled(isEnabled)
        }

        actionBarView.onResetTapped = { [weak self] in
            self?.resetCurrentPhoto()
        }

        actionBarView.onModeTapped = { [weak self] in
            self?.toggleEditorMode()
        }

        controlsView.onBrightnessChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.brightness = value
            }
        }

        controlsView.onContrastChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.contrast = value
            }
        }

        controlsView.onSaturationChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.saturation = value
            }
        }

        controlsView.onTemperatureChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.temperature = value
            }
        }

        controlsView.onTintChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.tint = value
            }
        }

        controlsView.onVibranceChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.vibrance = value
            }
        }

        controlsView.onExposureChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.exposure = value
            }
        }

        controlsView.onShadowsChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.shadows = value
            }
        }

        controlsView.onHighlightsChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.highlights = value
            }
        }

        controlsView.onWhitesChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.whites = value
            }
        }

        controlsView.onBlacksChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.blacks = value
            }
        }

        controlsView.onBlurChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.blurRadius = value
            }
        }

        controlsView.onSharpenChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.sharpen = value
            }
        }

        controlsView.onVignetteChanged = { [weak self] value in
            self?.updateRecipeManually {
                $0.vignette = value
            }
        }

        filmstripView.onPhotoSelected = { [weak self] index in
            self?.showPhoto(at: index)
        }

        presetPickerView.onPresetSelected = { [weak self] preset in
            guard let self else { return }
            selectedPreset = preset
        }
    }

    private func effectiveRecipe(for baseRecipe: EditRecipe) -> EditRecipe {
        selectedPreset.applying(to: baseRecipe)
    }

    private func showPhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        guard index != currentPhotoIndex else { return }

        previewRenderRequest?.cancel()
        previewRenderRequest = nil

        autoRequestID = nil
        isShowingOriginal = false

        currentPhotoIndex = index
        updateTitle()

        filmstripView.setSelectedIndex(index, animated: true)

        let requestID = UUID()
        photoSwitchRequestID = requestID

        let photo = photos[index]
        setPhotoLoading(true)

        renderQueue.async { [weak self] in
            let previewImage = photo.originalImage.resizedForEditorPreview(
                maxPixelSize: 1200
            )

            let previewCIImage = CIImage(image: previewImage) ?? CIImage()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard photoSwitchRequestID == requestID else { return }
                guard currentPhotoIndex == index else { return }

                photoSwitchRequestID = nil
                originalImage = photo.originalImage
                self.previewImage = previewImage
                self.previewCIImage = previewCIImage
                renderedPreviewImage = nil

                recipeBeforeAuto = photo.recipeBeforeAuto

                controlsView.setRecipe(
                    photo.recipe,
                    animated: false
                )

                actionBarView.setAutoEnabled(photo.recipeBeforeAuto != nil)

                editorImageView.setImage(
                    previewImage,
                    resetZoom: true
                )

                isApplyingPhotoState = true
                recipe = photo.recipe
                isApplyingPhotoState = false

                scheduleRenderPreview()
                setPhotoLoading(false)
            }
        }
    }

    private func setPhotoLoading(_ isLoading: Bool) {
        controlsView.isUserInteractionEnabled = !isLoading
        presetPickerView.isUserInteractionEnabled = !isLoading
        actionBarView.isUserInteractionEnabled = !isLoading

        navigationItem.rightBarButtonItems?.forEach {
            $0.isEnabled = !isLoading
        }

        if isLoading {
            progressLabel.text = "Loading photo…"
            progressOverlayView.isHidden = false

            activityIndicator.startAnimating()
            view.bringSubviewToFront(progressOverlayView)
        } else {
            activityIndicator.stopAnimating()

            progressOverlayView.isHidden = true
            progressLabel.text = nil
        }
    }

    private func setRecipeBeforeAuto(
        _ newRecipe: EditRecipe?
    ) {
        recipeBeforeAuto = newRecipe
        guard photos.indices.contains(currentPhotoIndex) else {
            return
        }
        photos[currentPhotoIndex].recipeBeforeAuto = newRecipe
        scheduleCollectionSave()
    }

    private func updateRecipeManually(
        _ update: (inout EditRecipe) -> Void
    ) {
        if autoRequestID != nil {
            autoRequestID = nil
            setRecipeBeforeAuto(nil)
            actionBarView.setAutoEnabled(false)
        }
        update(&recipe)
    }

    private func resetCurrentPhoto() {
        autoRequestID = nil
        setRecipeBeforeAuto(nil)

        actionBarView.setAutoEnabled(false)

        recipe = .neutral
        controlsView.setRecipe(.neutral, animated: true)

        selectedPreset = .none
        presetPickerView.setSelectedPreset(.none, animated: true)
    }

    private func setAutoEnabled(_ isEnabled: Bool) {
        if isEnabled {
            applyAutoAdjustments()
        } else {
            restoreRecipeBeforeAuto()
        }
    }

    private func applyAutoAdjustments() {
        guard recipeBeforeAuto == nil else {
            return
        }

        let baseRecipe = recipe
        let inputImage = previewCIImage
        let service = autoAdjustmentService

        setRecipeBeforeAuto(baseRecipe)

        let requestID = UUID()
        autoRequestID = requestID

        autoQueue.async { [weak self] in
            let autoRecipe = service.makeRecipe(
                for: inputImage,
                baseRecipe: baseRecipe
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard autoRequestID == requestID else { return }

                autoRequestID = nil

                controlsView.setRecipe(
                    autoRecipe,
                    animated: true
                )

                recipe = autoRecipe
            }
        }
    }

    private func applyAutoToAllPhotos() {
        guard photos.count > 1 else { return }
        guard !isExporting, !isApplyingAutoToAll else { return }

        if autoRequestID != nil {
            autoRequestID = nil
            setRecipeBeforeAuto(nil)
            actionBarView.setAutoEnabled(false)
        }

        let photosSnapshot = photos

        setApplyingAutoToAll(true, totalCount: photosSnapshot.count)

        Task { @MainActor [weak self] in
            guard let self else { return }

            var updatedPhotos = photosSnapshot
            var appliedCount = 0
            var skippedCount = 0

            for index in updatedPhotos.indices {
                updateAutoForAllProgress(current: index + 1, total: updatedPhotos.count)

                let photo = updatedPhotos[index]

                guard photo.recipeBeforeAuto == nil else {
                    skippedCount += 1
                    continue
                }

                let autoRecipe = await makeAutoRecipe(
                    for: photo.originalImage,
                    baseRecipe: photo.recipe
                )

                updatedPhotos[index].recipeBeforeAuto = photo.recipe
                updatedPhotos[index].recipe = autoRecipe
                appliedCount += 1
            }

            photos = updatedPhotos
            scheduleCollectionSave()

            applyCurrentPhotoStateAfterAutoForAll()
            setApplyingAutoToAll(false)

            showAutoForAllResult(
                appliedCount: appliedCount,
                skippedCount: skippedCount
            )
        }
    }

    private func makeAutoRecipe(for image: UIImage, baseRecipe: EditRecipe) async -> EditRecipe {
        let service = autoAdjustmentService

        return await withCheckedContinuation { continuation in
            autoQueue.async {
                let autoRecipe = autoreleasepool {
                    let previewImage = image.resizedForEditorPreview(maxPixelSize: 1200)
                    let inputImage = CIImage(image: previewImage) ?? CIImage()

                    return service.makeRecipe(
                        for: inputImage,
                        baseRecipe: baseRecipe
                    )
                }

                continuation.resume(returning: autoRecipe)
            }
        }
    }

    @MainActor
    private func applyCurrentPhotoStateAfterAutoForAll() {
        guard photos.indices.contains(currentPhotoIndex) else { return }

        let currentPhoto = photos[currentPhotoIndex]

        recipeBeforeAuto = currentPhoto.recipeBeforeAuto
        renderedPreviewImage = nil
        isShowingOriginal = false

        actionBarView.setAutoEnabled(currentPhoto.recipeBeforeAuto != nil)
        controlsView.setRecipe(currentPhoto.recipe, animated: true)

        recipe = currentPhoto.recipe
    }

    @MainActor
    private func setApplyingAutoToAll(_ isApplying: Bool, totalCount: Int = 0) {
        isApplyingAutoToAll = isApplying

        navigationItem.rightBarButtonItems?.forEach {
            $0.isEnabled = !isApplying
        }

        navigationItem.hidesBackButton = isApplying

        controlsView.isUserInteractionEnabled = !isApplying
        filmstripView.isUserInteractionEnabled = !isApplying
        presetPickerView.isUserInteractionEnabled = !isApplying
        editorImageView.isUserInteractionEnabled = !isApplying
        actionBarView.isUserInteractionEnabled = !isApplying

        if isApplying {
            progressLabel.text = "Preparing Auto for \(totalCount) photos…"
            progressOverlayView.isHidden = false

            activityIndicator.startAnimating()
            view.bringSubviewToFront(progressOverlayView)
        } else {
            activityIndicator.stopAnimating()

            progressOverlayView.isHidden = true
            progressLabel.text = nil
        }
    }

    @MainActor
    private func showAutoForAllResult(appliedCount: Int, skippedCount: Int) {
        if appliedCount == 0 {
            showAlert(
                title: "Auto",
                message: "All photos already have Auto enabled."
            )

            return
        }

        var message = "Auto was applied to \(appliedCount) photos."

        if skippedCount > 0 {
            message += " \(skippedCount) photos already had Auto and were left unchanged."
        }

        showAlert(
            title: "Auto Complete",
            message: message
        )
    }

    @MainActor
    private func updateAutoForAllProgress(current: Int, total: Int) {
        progressLabel.text = "Applying Auto \(current) of \(total)"
    }

    private func restoreRecipeBeforeAuto() {
        autoRequestID = nil

        guard let previousRecipe = recipeBeforeAuto else {
            return
        }

        setRecipeBeforeAuto(nil)

        controlsView.setRecipe(
            previousRecipe,
            animated: true
        )

        recipe = previousRecipe
    }

    private func scheduleRenderPreview() {
        previewRenderRequest?.cancel()

        let currentRecipe = effectiveRecipe(for: recipe)

        guard !currentRecipe.isNeutral else {
            previewRenderRequest = nil
            renderedPreviewImage = nil

            if !isShowingOriginal {
                editorImageView.image = previewImage
            }

            return
        }

        let inputImage = previewCIImage
        let pipeline = filterPipeline

        let request = PreviewRenderRequest(
            render: {
                pipeline.renderPreview(
                    ciImage: inputImage,
                    recipe: currentRecipe
                )
            },
            completion: { [weak self] renderID, renderedImage in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard previewRenderRequest?.id == renderID else { return }
                    guard previewRenderRequest?.isCancelled == false else { return }
                    guard let renderedImage else { return }

                    renderedPreviewImage = renderedImage

                    guard !isShowingOriginal else { return }

                    editorImageView.image = renderedImage
                }
            }
        )

        previewRenderRequest = request
        renderQueue.async(execute: request.workItem)
    }

    private func exportCurrentPhoto() {
        guard photos.indices.contains(currentPhotoIndex) else { return }
        photos[currentPhotoIndex].recipe = recipe
        startExport(photosToExport: [photos[currentPhotoIndex]])
    }

    private func exportAllPhotos() {
        guard !photos.isEmpty else { return }
        guard photos.indices.contains(currentPhotoIndex) else { return }
        photos[currentPhotoIndex].recipe = recipe
        startExport(photosToExport: photos)
    }

    private func startExport(
        photosToExport: [EditablePhoto]
    ) {
        guard !isExporting else { return }
        guard !isApplyingAutoToAll else { return }
        guard !photosToExport.isEmpty else { return }

        setExporting(true, totalCount: photosToExport.count)

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await exportService.requestAddOnlyAccess()
            } catch {
                setExporting(false)
                showAlert(title: "Ошибка экспорта", message: error.localizedDescription)
                return
            }

            var exportedCount = 0
            var failedCount = 0
            var lastError: Error?

            for (index, photo) in photosToExport.enumerated() {
                updateExportProgress(
                    current: index + 1,
                    total: photosToExport.count
                )

                guard let renderedImage = await renderFullSize(photo: photo) else {
                    failedCount += 1
                    lastError = PhotoExportError.renderFailed
                    continue
                }

                do {
                    try await exportService.saveToPhotoLibrary(image: renderedImage)
                    exportedCount += 1
                } catch {
                    failedCount += 1
                    lastError = error
                }
            }

            setExporting(false)

            showExportResult(
                exportedCount: exportedCount,
                failedCount: failedCount,
                totalCount: photosToExport.count,
                lastError: lastError
            )
        }
    }

    @MainActor
    private func setExporting(_ isExporting: Bool, totalCount: Int = 0) {
        self.isExporting = isExporting

        navigationItem.rightBarButtonItems?.forEach {
            $0.isEnabled = !isExporting
        }

        navigationItem.hidesBackButton = isExporting

        controlsView.isUserInteractionEnabled = !isExporting
        filmstripView.isUserInteractionEnabled = !isExporting
        presetPickerView.isUserInteractionEnabled = !isExporting
        editorImageView.isUserInteractionEnabled = !isExporting
        actionBarView.isUserInteractionEnabled = !isExporting

        if isExporting {
            progressLabel.text = totalCount == 1
                ? "Exporting photo…"
                : "Preparing \(totalCount) photos…"

            progressOverlayView.isHidden = false

            activityIndicator.startAnimating()
            view.bringSubviewToFront(progressOverlayView)
        } else {
            activityIndicator.stopAnimating()

            progressOverlayView.isHidden = true
            progressLabel.text = nil
        }
    }

    @MainActor
    private func updateExportProgress(
        current: Int,
        total: Int
    ) {
        progressLabel.text = total == 1
            ? "Exporting photo…"
            : "Exporting \(current) of \(total)"
    }

    @MainActor
    private func showExportResult(
        exportedCount: Int,
        failedCount: Int,
        totalCount: Int,
        lastError: Error?
    ) {
        if exportedCount == totalCount {
            let message: String

            if totalCount == 1 {
                message = "Фото сохранено в галерею."
            } else {
                message = "\(exportedCount) photos saved to the gallery."
            }

            showAlert(title: "Готово", message: message)
            return
        }

        if exportedCount == 0 {
            showAlert(
                title: "Ошибка экспорта",
                message: lastError?.localizedDescription
                    ?? "Не удалось экспортировать фотографии."
            )
            return
        }

        showAlert(
            title: "Экспорт завершен",
            message:
                "\(exportedCount) of \(totalCount) photos exported. "
                + "\(failedCount) failed."
        )
    }

    private func renderFullSize(photo: EditablePhoto) async -> UIImage? {
        let pipeline = filterPipeline
        let queue = exportQueue
        let recipe = effectiveRecipe(for: photo.recipe)

        return await withCheckedContinuation { continuation in
            queue.async {
                let renderedImage = autoreleasepool {
                    pipeline.renderFullSize(
                        image: photo.originalImage,
                        recipe: recipe
                    )
                }

                continuation.resume(returning: renderedImage)
            }
        }
    }

    private func scheduleCollectionSave() {
        let storedPhotos = photos.map(\.storedPhoto)
        let selectedPresetID = selectedPreset.rawValue

        collectionSaveTask?.cancel()

        collectionSaveTask = Task {
            [collectionStorageService, collectionID, selectedPresetID] in

            try? await Task.sleep(nanoseconds: 600_000_000)

            guard !Task.isCancelled else { return }

            try? await collectionStorageService.updateCollection(
                id: collectionID,
                photos: storedPhotos,
                selectedPresetID: selectedPresetID
            )
        }
    }

    private func saveCollectionImmediately() {
        collectionSaveTask?.cancel()

        let storedPhotos = photos.map(\.storedPhoto)
        let selectedPresetID = selectedPreset.rawValue

        Task { [collectionStorageService, collectionID, selectedPresetID] in
            try? await collectionStorageService.updateCollection(
                id: collectionID,
                photos: storedPhotos,
                selectedPresetID: selectedPresetID
            )
        }
    }

    @MainActor
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func handleBeforeAfterGesture(
        _ gestureRecognizer: UILongPressGestureRecognizer
    ) {
        switch gestureRecognizer.state {
        case .began:
            isShowingOriginal = true
            editorImageView.image = previewImage

        case .ended, .cancelled, .failed:
            isShowingOriginal = false
            editorImageView.image = renderedPreviewImage ?? previewImage

        default:
            break
        }
    }

    private func applyCardStyle(to view: UIView, cornerRadius: CGFloat) {
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.025)
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 0.75
        view.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.14).cgColor
        view.clipsToBounds = true
    }

    private func setupContainerAppearance() {
        applyCardStyle(to: editorImageView, cornerRadius: 18)
        applyCardStyle(to: filmstripView, cornerRadius: 14)
        applyCardStyle(to: presetPickerView, cornerRadius: 14)
        applyCardStyle(to: actionBarView, cornerRadius: 16)
        applyCardStyle(to: controlsView, cornerRadius: 18)
    }
}

extension EditorViewController {

    private func setEditorMode(_ mode: EditorMode, animated: Bool) {
        editorMode = mode
        let showsAdjustments = mode == .adjustments
        actionBarView.setShowsAdjustments(showsAdjustments)

        guard animated else {
            controlsContainerView.layer.removeAllAnimations()
            controlsContainerView.alpha = 1
            controlsContainerView.isHidden = !showsAdjustments
            view.layoutIfNeeded()
            return
        }

        view.layoutIfNeeded()
        controlsContainerView.layer.removeAllAnimations()

        if showsAdjustments {
            controlsContainerView.alpha = 0
            controlsContainerView.isHidden = false

            UIView.animate(
                withDuration: 0.24,
                delay: 0,
                options: [.curveEaseInOut, .beginFromCurrentState],
                animations: {
                    self.controlsContainerView.alpha = 1
                    self.view.layoutIfNeeded()
                }
            )
        } else {
            UIView.animate(
                withDuration: 0.10,
                delay: 0,
                options: [.curveEaseIn, .beginFromCurrentState],
                animations: {
                    self.controlsContainerView.alpha = 0
                },
                completion: { [weak self] _ in
                    guard let self else { return }
                    guard editorMode == .styles else { return }

                    controlsContainerView.isHidden = true
                    controlsContainerView.alpha = 1

                    UIView.animate(
                        withDuration: 0.14,
                        delay: 0,
                        options: [.curveEaseOut, .beginFromCurrentState],
                        animations: {
                            self.view.layoutIfNeeded()
                        }
                    )
                }
            )
        }
    }

    private func toggleEditorMode() {
        switch editorMode {
        case .styles:
            setEditorMode(.adjustments, animated: true)

        case .adjustments:
            setEditorMode(.styles, animated: true)
        }
    }
}
