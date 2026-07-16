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

    private var renderWorkItem: DispatchWorkItem?
    private var renderGeneration = 0

    private let exportService = PhotoExportService()
    private let exportQueue = DispatchQueue(label: "PhotoLab.editor.export", qos: .userInitiated)

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private var recipe = EditRecipe() {
        didSet {
            scheduleRenderPreview()
        }
    }

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .secondarySystemBackground
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
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

    private let controlsScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        return scrollView
    }()

    private let controlsContentView = UIView()

    private let slidersStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 22
        stackView.alignment = .fill
        stackView.distribution = .fill
        return stackView
    }()

    private let resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Reset", for: .normal)
        button.configuration = .bordered()
        return button
    }()

    init(image: UIImage) {
        self.originalImage = image

        let preview = image.resizedForEditorPreview(maxPixelSize: 1600)
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

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Editor"
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        setupLayout()
        setupActions()

        imageView.image = previewImage
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
        view.addSubview(controlsScrollView)
        view.addSubview(activityIndicator)

        controlsScrollView.addSubview(controlsContentView)

        controlsContentView.addSubview(slidersStackView)
        controlsContentView.addSubview(resetButton)

        slidersStackView.addArrangedSubview(brightnessSliderView)
        slidersStackView.addArrangedSubview(contrastSliderView)
        slidersStackView.addArrangedSubview(saturationSliderView)
        slidersStackView.addArrangedSubview(exposureSliderView)
        slidersStackView.addArrangedSubview(blurSliderView)
        slidersStackView.addArrangedSubview(sharpenSliderView)
        slidersStackView.addArrangedSubview(vignetteSliderView)

        imageView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalToSuperview().multipliedBy(0.42)
        }

        controlsScrollView.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        controlsContentView.snp.makeConstraints { make in
            make.edges.equalTo(controlsScrollView.contentLayoutGuide)
            make.width.equalTo(controlsScrollView.frameLayoutGuide)
        }

        slidersStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        resetButton.snp.makeConstraints { make in
            make.top.equalTo(slidersStackView.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.width.equalTo(120)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().inset(24)
        }

        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
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

        resetButton.addTarget(
            self,
            action: #selector(resetButtonTapped),
            for: .touchUpInside
        )
    }

    @objc private func resetButtonTapped() {
        recipe = EditRecipe()
        brightnessSliderView.setValue(recipe.brightness, animated: true)
        contrastSliderView.setValue(recipe.contrast, animated: true)
        saturationSliderView.setValue(recipe.saturation, animated: true)
        exposureSliderView.setValue(recipe.exposure, animated: true)
        blurSliderView.setValue(recipe.blurRadius, animated: true)
        sharpenSliderView.setValue(recipe.sharpen, animated: true)
        vignetteSliderView.setValue(recipe.vignette, animated: true)
    }

    private func scheduleRenderPreview() {
        renderGeneration += 1

        let currentGeneration = renderGeneration
        let currentRecipe = recipe
        let inputImage = previewCIImage
        let pipeline = filterPipeline

        renderWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            let renderedImage = pipeline.renderPreview(
                ciImage: inputImage,
                recipe: currentRecipe
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                guard currentGeneration == self.renderGeneration else {
                    return
                }

                guard let renderedImage else {
                    return
                }

                self.imageView.image = renderedImage
            }
        }

        renderWorkItem = workItem
        renderQueue.asyncAfter(deadline: .now() + 0.03, execute: workItem)
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
        resetButton.isEnabled = !isExporting
        controlsScrollView.isUserInteractionEnabled = !isExporting

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
}
