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

    private let originalImage: UIImage
    private let previewImage: UIImage
    private let previewCIImage: CIImage

    private let filterPipeline = FilterPipeline()
    private let renderQueue = DispatchQueue(label: "PhotoLab.editor.render", qos: .userInitiated)

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

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .secondarySystemBackground
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()

    private let controlsView = EditorControlsView()

    init(image: UIImage) {
        self.originalImage = image

        let preview = image.resizedForEditorPreview(maxPixelSize: 1200)
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

        title = "Editor"
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        setupLayout()
        setupActions()
        setupBeforeAfterGesture()

        imageView.image = previewImage
    }

    private func setupBeforeAfterGesture() {
        imageView.isUserInteractionEnabled = true

        let gestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleBeforeAfterGesture)
        )

        gestureRecognizer.minimumPressDuration = 0
        gestureRecognizer.cancelsTouchesInView = false

        imageView.addGestureRecognizer(gestureRecognizer)
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
        view.addSubview(imageView)
        view.addSubview(controlsView)
        view.addSubview(activityIndicator)

        controlsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        imageView.snp.makeConstraints { make in
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
            self?.recipe.brightness = value
        }

        controlsView.onContrastChanged = { [weak self] value in
            self?.recipe.contrast = value
        }

        controlsView.onSaturationChanged = { [weak self] value in
            self?.recipe.saturation = value
        }

        controlsView.onExposureChanged = { [weak self] value in
            self?.recipe.exposure = value
        }

        controlsView.onBlurChanged = { [weak self] value in
            self?.recipe.blurRadius = value
        }

        controlsView.onSharpenChanged = { [weak self] value in
            self?.recipe.sharpen = value
        }

        controlsView.onVignetteChanged = { [weak self] value in
            self?.recipe.vignette = value
        }

        controlsView.onResetAll = { [weak self] in
            self?.recipe = .neutral
        }
    }

    private func scheduleRenderPreview() {
        previewRenderRequest?.cancel()

        guard !recipe.isNeutral else {
            previewRenderRequest = nil
            renderedPreviewImage = nil
            if !isShowingOriginal {
                imageView.image = previewImage
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

                    imageView.image = renderedImage
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
            imageView.image = previewImage

        case .ended, .cancelled, .failed:
            isShowingOriginal = false
            imageView.image = renderedPreviewImage ?? previewImage

        default:
            break
        }
    }
}
