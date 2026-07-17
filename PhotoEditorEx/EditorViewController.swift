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

    private let brightnessSliderView = AdjustmentSliderView(
        title: "Brightness",
        minimumValue: -0.5,
        maximumValue: 0.5,
        value: 0
    )

    private let contrastSliderView = AdjustmentSliderView(
        title: "Contrast",
        minimumValue: 0.5,
        maximumValue: 2.0,
        value: 1
    )

    private let saturationSliderView = AdjustmentSliderView(
        title: "Saturation",
        minimumValue: 0,
        maximumValue: 2.0,
        value: 1
    )

    private let exposureSliderView = AdjustmentSliderView(
        title: "Exposure",
        minimumValue: -2,
        maximumValue: 2,
        value: 0
    )

    private let blurSliderView = AdjustmentSliderView(
        title: "Blur",
        minimumValue: 0,
        maximumValue: 20,
        value: 0,
        valueFormatter: { String(format: "%.1f", $0) }
    )

    private let sharpenSliderView = AdjustmentSliderView(
        title: "Sharpen",
        minimumValue: 0,
        maximumValue: 2,
        value: 0
    )

    private let vignetteSliderView = AdjustmentSliderView(
        title: "Vignette",
        minimumValue: 0,
        maximumValue: 2,
        value: 0
    )

    private let controlsContainerView = UIView()

    private let activeSliderContainerView = UIView()

    private let toolsScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return scrollView
    }()

    private let toolsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .fill
        stackView.distribution = .fill
        return stackView
    }()

    private var activeSliderView: AdjustmentSliderView?
    private var selectedToolButton: UIButton?

    private let brightnessToolButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.gray()
        configuration.title = "Brightness"
        configuration.cornerStyle = .medium
        button.configuration = configuration
        return button
    }()

    private let contrastToolButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.gray()
        configuration.title = "Contrast"
        configuration.cornerStyle = .medium
        button.configuration = configuration
        return button
    }()

    private let saturationToolButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.gray()
        configuration.title = "Saturation"
        configuration.cornerStyle = .medium
        button.configuration = configuration
        return button
    }()

    private let exposureToolButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.gray()
        configuration.title = "Exposure"
        configuration.cornerStyle = .medium
        button.configuration = configuration
        return button
    }()

    private let blurToolButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.gray()
        configuration.title = "Blur"
        configuration.cornerStyle = .medium
        button.configuration = configuration
        return button
    }()

    private let sharpenToolButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.gray()
        configuration.title = "Sharpen"
        configuration.cornerStyle = .medium
        button.configuration = configuration
        return button
    }()

    private let vignetteToolButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.gray()
        configuration.title = "Vignette"
        configuration.cornerStyle = .medium
        button.configuration = configuration
        return button
    }()

    private let resetCurrentButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Reset", for: .normal)
        button.configuration = .bordered()
        return button
    }()

    private let resetAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Reset All", for: .normal)
        button.configuration = .bordered()
        return button
    }()

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
        view.addSubview(controlsContainerView)
        view.addSubview(activityIndicator)

        controlsContainerView.addSubview(activeSliderContainerView)
        controlsContainerView.addSubview(toolsScrollView)
        controlsContainerView.addSubview(resetAllButton)
        controlsContainerView.addSubview(resetCurrentButton)

        toolsScrollView.addSubview(toolsStackView)

        toolsStackView.addArrangedSubview(brightnessToolButton)
        toolsStackView.addArrangedSubview(contrastToolButton)
        toolsStackView.addArrangedSubview(saturationToolButton)
        toolsStackView.addArrangedSubview(exposureToolButton)
        toolsStackView.addArrangedSubview(blurToolButton)
        toolsStackView.addArrangedSubview(sharpenToolButton)
        toolsStackView.addArrangedSubview(vignetteToolButton)

        controlsContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        imageView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(controlsContainerView.snp.top)
        }

        activeSliderContainerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(64)
        }

        toolsScrollView.snp.makeConstraints { make in
            make.top.equalTo(activeSliderContainerView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(44)
        }

        toolsStackView.snp.makeConstraints { make in
            make.edges.equalTo(toolsScrollView.contentLayoutGuide)
            make.height.equalTo(toolsScrollView.frameLayoutGuide)
        }

        resetCurrentButton.snp.makeConstraints { make in
            make.top.equalTo(toolsScrollView.snp.bottom).offset(12)
            make.trailing.equalTo(controlsContainerView.snp.centerX).offset(-6)
            make.width.equalTo(120)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().inset(16)
        }

        resetAllButton.snp.makeConstraints { make in
            make.top.equalTo(resetCurrentButton)
            make.leading.equalTo(controlsContainerView.snp.centerX).offset(6)
            make.width.equalTo(resetCurrentButton)
            make.height.equalTo(resetCurrentButton)
        }

        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        showAdjustment(
            brightnessSliderView,
            selectedButton: brightnessToolButton
        )
    }

    private func setupActions() {
        brightnessSliderView.onValueChanged = { [weak self] value in
            self?.recipe.brightness = value
        }

        contrastSliderView.onValueChanged = { [weak self] value in
            self?.recipe.contrast = value
        }

        saturationSliderView.onValueChanged = { [weak self] value in
            self?.recipe.saturation = value
        }

        exposureSliderView.onValueChanged = { [weak self] value in
            self?.recipe.exposure = value
        }

        blurSliderView.onValueChanged = { [weak self] value in
            self?.recipe.blurRadius = value
        }

        sharpenSliderView.onValueChanged = { [weak self] value in
            self?.recipe.sharpen = value
        }

        vignetteSliderView.onValueChanged = { [weak self] value in
            self?.recipe.vignette = value
        }

        brightnessToolButton.addTarget(
            self,
            action: #selector(brightnessToolButtonTapped),
            for: .touchUpInside
        )

        contrastToolButton.addTarget(
            self,
            action: #selector(contrastToolButtonTapped),
            for: .touchUpInside
        )

        saturationToolButton.addTarget(
            self,
            action: #selector(saturationToolButtonTapped),
            for: .touchUpInside
        )

        exposureToolButton.addTarget(
            self,
            action: #selector(exposureToolButtonTapped),
            for: .touchUpInside
        )

        blurToolButton.addTarget(
            self,
            action: #selector(blurToolButtonTapped),
            for: .touchUpInside
        )

        sharpenToolButton.addTarget(
            self,
            action: #selector(sharpenToolButtonTapped),
            for: .touchUpInside
        )

        vignetteToolButton.addTarget(
            self,
            action: #selector(vignetteToolButtonTapped),
            for: .touchUpInside
        )

        resetCurrentButton.addTarget(
            self,
            action: #selector(resetCurrentButtonTapped),
            for: .touchUpInside
        )

        resetAllButton.addTarget(
            self,
            action: #selector(resetAllButtonTapped),
            for: .touchUpInside
        )
    }

    @objc private func brightnessToolButtonTapped() {
        showAdjustment(
            brightnessSliderView,
            selectedButton: brightnessToolButton
        )
    }

    @objc private func contrastToolButtonTapped() {
        showAdjustment(
            contrastSliderView,
            selectedButton: contrastToolButton
        )
    }

    @objc private func saturationToolButtonTapped() {
        showAdjustment(
            saturationSliderView,
            selectedButton: saturationToolButton
        )
    }

    @objc private func exposureToolButtonTapped() {
        showAdjustment(
            exposureSliderView,
            selectedButton: exposureToolButton
        )
    }

    @objc private func blurToolButtonTapped() {
        showAdjustment(
            blurSliderView,
            selectedButton: blurToolButton
        )
    }

    @objc private func sharpenToolButtonTapped() {
        showAdjustment(
            sharpenSliderView,
            selectedButton: sharpenToolButton
        )
    }

    @objc private func vignetteToolButtonTapped() {
        showAdjustment(
            vignetteSliderView,
            selectedButton: vignetteToolButton
        )
    }

    private func showAdjustment(
        _ sliderView: AdjustmentSliderView,
        selectedButton: UIButton
    ) {
        guard activeSliderView !== sliderView else {
            return
        }

        activeSliderView?.removeFromSuperview()

        activeSliderView = sliderView
        activeSliderContainerView.addSubview(sliderView)

        sliderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        updateToolButton(
            self.selectedToolButton,
            isSelected: false
        )

        self.selectedToolButton = selectedButton

        updateToolButton(
            selectedButton,
            isSelected: true
        )
    }

    private func updateToolButton(
        _ button: UIButton?,
        isSelected: Bool
    ) {
        guard let button else {
            return
        }

        let title = button.configuration?.title

        var configuration: UIButton.Configuration

        if isSelected {
            configuration = .filled()
        } else {
            configuration = .gray()
        }

        configuration.title = title
        configuration.cornerStyle = .medium

        button.configuration = configuration
    }

    @objc private func resetAllButtonTapped() {
        let neutralRecipe = EditRecipe.neutral
        updateControls(with: neutralRecipe, animated: true)
        recipe = neutralRecipe
    }

    @objc private func resetCurrentButtonTapped() {
        if activeSliderView === brightnessSliderView {
            brightnessSliderView.setValue(0, animated: true)
            recipe.brightness = 0
        } else if activeSliderView === contrastSliderView {
            contrastSliderView.setValue(1, animated: true)
            recipe.contrast = 1
        } else if activeSliderView === saturationSliderView {
            saturationSliderView.setValue(1, animated: true)
            recipe.saturation = 1
        } else if activeSliderView === exposureSliderView {
            exposureSliderView.setValue(0, animated: true)
            recipe.exposure = 0
        } else if activeSliderView === blurSliderView {
            blurSliderView.setValue(0, animated: true)
            recipe.blurRadius = 0
        } else if activeSliderView === sharpenSliderView {
            sharpenSliderView.setValue(0, animated: true)
            recipe.sharpen = 0
        } else if activeSliderView === vignetteSliderView {
            vignetteSliderView.setValue(0, animated: true)
            recipe.vignette = 0
        }
    }

    private func updateControls(
        with recipe: EditRecipe,
        animated: Bool
    ) {
        brightnessSliderView.setValue(recipe.brightness, animated: animated)
        contrastSliderView.setValue(recipe.contrast, animated: animated)
        saturationSliderView.setValue(recipe.saturation, animated: animated)
        exposureSliderView.setValue(recipe.exposure, animated: animated)
        blurSliderView.setValue(recipe.blurRadius, animated: animated)
        sharpenSliderView.setValue(recipe.sharpen, animated: animated)
        vignetteSliderView.setValue(recipe.vignette, animated: animated)
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

        resetCurrentButton.isEnabled = !isExporting
        resetAllButton.isEnabled = !isExporting

        controlsContainerView.isUserInteractionEnabled = !isExporting

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
