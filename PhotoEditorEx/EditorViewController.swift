//
//  EditorViewController.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 01.07.2026.
//

import UIKit
import CoreImage
import SnapKit

final class EditorViewController: UIViewController {

    private var photos: [EditablePhoto]

    private let originalImage: UIImage
    private let previewImage: UIImage
    private let previewCIImage: CIImage

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
    private let exportQueue = DispatchQueue(label: "PhotoLab.editor.export", qos: .userInitiated)

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private var recipe: EditRecipe = .neutral {
        didSet {
            guard oldValue != recipe else {
                return
            }
            scheduleRenderPreview()
        }
    }

    private var renderedPreviewImage: UIImage?
    private var isShowingOriginal = false

    private let editorImageView = EditorImageView()
    private let controlsView = EditorControlsView()

    init(photos: [EditablePhoto]) {
        guard let firstPhoto = photos.first else {
            fatalError("EditorViewController requires at least one photo")
        }

        self.photos = photos
        self.originalImage = firstPhoto.originalImage

        let preview = firstPhoto.originalImage.resizedForEditorPreview(
            maxPixelSize: 1200
        )

        self.previewImage = preview

        if let ciImage = CIImage(image: preview) {
            self.previewCIImage = ciImage
        } else {
            self.previewCIImage = CIImage()
        }

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        previewRenderRequest?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateTitle()
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        setupLayout()
        setupActions()
        setupBeforeAfterGesture()

        editorImageView.image = previewImage
    }

    private func updateTitle() {
        if photos.count == 1 {
            title = "Editor"
        } else {
            title = "1 of \(photos.count)"
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Export",
            style: .done,
            target: self,
            action: #selector(exportButtonTapped)
        )
    }

    private func setupLayout() {
        view.addSubview(editorImageView)
        view.addSubview(controlsView)
        view.addSubview(activityIndicator)

        controlsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        editorImageView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(controlsView.snp.top)
        }

        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func setupActions() {
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

        controlsView.onAutoChanged = { [weak self] isEnabled in
            self?.setAutoEnabled(isEnabled)
        }

        controlsView.onResetAll = { [weak self] in
            guard let self else { return }

            autoRequestID = nil
            recipeBeforeAuto = nil

            controlsView.setAutoEnabled(false)
            recipe = .neutral
        }
    }

    private func updateRecipeManually(
        _ update: (inout EditRecipe) -> Void
    ) {
        if autoRequestID != nil {
            autoRequestID = nil
            recipeBeforeAuto = nil
            controlsView.setAutoEnabled(false)
        }
        update(&recipe)
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

        recipeBeforeAuto = baseRecipe

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

    private func restoreRecipeBeforeAuto() {
        autoRequestID = nil

        guard let previousRecipe = recipeBeforeAuto else {
            return
        }

        recipeBeforeAuto = nil

        controlsView.setRecipe(
            previousRecipe,
            animated: true
        )

        recipe = previousRecipe
    }

    private func scheduleRenderPreview() {
        previewRenderRequest?.cancel()

        guard !recipe.isNeutral else {
            previewRenderRequest = nil
            renderedPreviewImage = nil

            if !isShowingOriginal {
                editorImageView.image = previewImage
            }

            return
        }

        let currentRecipe = recipe
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

    @objc private func exportButtonTapped() {
        setExporting(true)

        let currentRecipe = recipe
        let image = originalImage
        let pipeline = filterPipeline
        let exportService = exportService

        exportQueue.async { [weak self] in
            guard let renderedImage = pipeline.renderFullSize(
                image: image,
                recipe: currentRecipe
            ) else {
                DispatchQueue.main.async {
                    self?.setExporting(false)
                    self?.showAlert(
                        title: "Ошибка",
                        message: "Не удалось отрендерить изображение."
                    )
                }
                return
            }

            exportService.saveToPhotoLibrary(image: renderedImage) { [weak self] result in
                self?.setExporting(false)

                switch result {
                case .success:
                    self?.showAlert(
                        title: "Готово",
                        message: "Фото сохранено в галерею."
                    )

                case .failure(let error):
                    self?.showAlert(
                        title: "Ошибка экспорта",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    private func setExporting(_ isExporting: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = !isExporting
        controlsView.isUserInteractionEnabled = !isExporting

        if isExporting {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

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
}
