//
//  EditorControlsView.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 17.07.2026.
//

import UIKit
import SnapKit

final class EditorControlsView: UIView {

    var onBrightnessChanged: ((Float) -> Void)?
    var onContrastChanged: ((Float) -> Void)?
    var onSaturationChanged: ((Float) -> Void)?
    var onExposureChanged: ((Float) -> Void)?
    var onBlurChanged: ((Float) -> Void)?
    var onSharpenChanged: ((Float) -> Void)?
    var onVignetteChanged: ((Float) -> Void)?
    var onResetAll: (() -> Void)?

    private let activeSliderContainerView = UIView()

    private let brightnessSliderView = AdjustmentSliderView(
        title: "Brightness",
        minimumValue: -0.5,
        maximumValue: 0.5,
        value: 0
    )

    private let contrastSliderView = AdjustmentSliderView(
        title: "Contrast",
        minimumValue: 0.5,
        maximumValue: 2,
        value: 1
    )

    private let saturationSliderView = AdjustmentSliderView(
        title: "Saturation",
        minimumValue: 0,
        maximumValue: 2,
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
        valueFormatter: {
            String(format: "%.1f", $0)
        }
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

    private let toolsScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        return scrollView
    }()

    private let toolsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.alignment = .fill
        stackView.distribution = .fill
        return stackView
    }()

    private let brightnessToolButton = EditorControlsView.makeToolButton(
        systemName: "sun.max.fill",
        fallbackSystemName: "sun.max",
        accessibilityLabel: "Brightness"
    )

    private let contrastToolButton = EditorControlsView.makeToolButton(
        systemName: "circle.lefthalf.filled",
        fallbackSystemName: "circle.lefthalf.fill",
        accessibilityLabel: "Contrast"
    )

    private let saturationToolButton = EditorControlsView.makeToolButton(
        systemName: "paintpalette.fill",
        fallbackSystemName: "paintpalette",
        accessibilityLabel: "Saturation"
    )

    private let exposureToolButton = EditorControlsView.makeToolButton(
        systemName: "plusminus.circle.fill",
        fallbackSystemName: "plusminus.circle",
        accessibilityLabel: "Exposure"
    )

    private let blurToolButton = EditorControlsView.makeToolButton(
        systemName: "drop.fill",
        fallbackSystemName: "drop",
        accessibilityLabel: "Blur"
    )

    private let sharpenToolButton = EditorControlsView.makeToolButton(
        systemName: "scope",
        fallbackSystemName: "viewfinder",
        accessibilityLabel: "Sharpen"
    )

    private let vignetteToolButton = EditorControlsView.makeToolButton(
        systemName: "circle.dashed.inset.filled",
        fallbackSystemName: "circle.dashed",
        accessibilityLabel: "Vignette"
    )

    private let resetCurrentButton: UIButton = {
        let button = UIButton(type: .system)

        var configuration = UIButton.Configuration.bordered()
        configuration.title = "Reset"

        button.configuration = configuration
        return button
    }()

    private let resetAllButton: UIButton = {
        let button = UIButton(type: .system)

        var configuration = UIButton.Configuration.bordered()
        configuration.title = "Reset All"

        button.configuration = configuration
        return button
    }()

    private var activeSliderView: AdjustmentSliderView?
    private var selectedToolButton: UIButton?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground

        setupLayout()
        setupActions()

        showAdjustment(
            brightnessSliderView,
            selectedButton: brightnessToolButton
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupLayout() {
        addSubview(activeSliderContainerView)
        addSubview(toolsScrollView)
        addSubview(resetCurrentButton)
        addSubview(resetAllButton)

        toolsScrollView.addSubview(toolsStackView)

        toolsStackView.addArrangedSubview(brightnessToolButton)
        toolsStackView.addArrangedSubview(contrastToolButton)
        toolsStackView.addArrangedSubview(saturationToolButton)
        toolsStackView.addArrangedSubview(exposureToolButton)
        toolsStackView.addArrangedSubview(blurToolButton)
        toolsStackView.addArrangedSubview(sharpenToolButton)
        toolsStackView.addArrangedSubview(vignetteToolButton)

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

        brightnessToolButton.snp.makeConstraints { make in
            make.width.equalTo(44)
        }

        contrastToolButton.snp.makeConstraints { make in
            make.width.equalTo(brightnessToolButton)
        }

        saturationToolButton.snp.makeConstraints { make in
            make.width.equalTo(brightnessToolButton)
        }

        exposureToolButton.snp.makeConstraints { make in
            make.width.equalTo(brightnessToolButton)
        }

        blurToolButton.snp.makeConstraints { make in
            make.width.equalTo(brightnessToolButton)
        }

        sharpenToolButton.snp.makeConstraints { make in
            make.width.equalTo(brightnessToolButton)
        }

        vignetteToolButton.snp.makeConstraints { make in
            make.width.equalTo(brightnessToolButton)
        }

        resetCurrentButton.snp.makeConstraints { make in
            make.top.equalTo(toolsScrollView.snp.bottom).offset(12)
            make.trailing.equalTo(snp.centerX).offset(-6)
            make.width.equalTo(120)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().inset(16)
        }

        resetAllButton.snp.makeConstraints { make in
            make.top.equalTo(resetCurrentButton)
            make.leading.equalTo(snp.centerX).offset(6)
            make.width.equalTo(resetCurrentButton)
            make.height.equalTo(resetCurrentButton)
        }
    }

    private func setupActions() {
        brightnessSliderView.onValueChanged = { [weak self] value in
            self?.onBrightnessChanged?(value)
        }

        contrastSliderView.onValueChanged = { [weak self] value in
            self?.onContrastChanged?(value)
        }

        saturationSliderView.onValueChanged = { [weak self] value in
            self?.onSaturationChanged?(value)
        }

        exposureSliderView.onValueChanged = { [weak self] value in
            self?.onExposureChanged?(value)
        }

        blurSliderView.onValueChanged = { [weak self] value in
            self?.onBlurChanged?(value)
        }

        sharpenSliderView.onValueChanged = { [weak self] value in
            self?.onSharpenChanged?(value)
        }

        vignetteSliderView.onValueChanged = { [weak self] value in
            self?.onVignetteChanged?(value)
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
        guard let button else { return }

        UIView.animate(withDuration: 0.2) {
            button.tintColor = isSelected
                ? .systemBlue
                : .secondaryLabel

            button.backgroundColor = isSelected
                ? UIColor.systemBlue.withAlphaComponent(0.12)
                : .clear
        }

        if isSelected {
            button.accessibilityTraits.insert(.selected)
        } else {
            button.accessibilityTraits.remove(.selected)
        }
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

    @objc private func resetCurrentButtonTapped() {
        if activeSliderView === brightnessSliderView {
            brightnessSliderView.setValue(0, animated: true)
            onBrightnessChanged?(0)
        } else if activeSliderView === contrastSliderView {
            contrastSliderView.setValue(1, animated: true)
            onContrastChanged?(1)
        } else if activeSliderView === saturationSliderView {
            saturationSliderView.setValue(1, animated: true)
            onSaturationChanged?(1)
        } else if activeSliderView === exposureSliderView {
            exposureSliderView.setValue(0, animated: true)
            onExposureChanged?(0)
        } else if activeSliderView === blurSliderView {
            blurSliderView.setValue(0, animated: true)
            onBlurChanged?(0)
        } else if activeSliderView === sharpenSliderView {
            sharpenSliderView.setValue(0, animated: true)
            onSharpenChanged?(0)
        } else if activeSliderView === vignetteSliderView {
            vignetteSliderView.setValue(0, animated: true)
            onVignetteChanged?(0)
        }
    }

    @objc private func resetAllButtonTapped() {
        brightnessSliderView.setValue(0, animated: true)
        contrastSliderView.setValue(1, animated: true)
        saturationSliderView.setValue(1, animated: true)
        exposureSliderView.setValue(0, animated: true)
        blurSliderView.setValue(0, animated: true)
        sharpenSliderView.setValue(0, animated: true)
        vignetteSliderView.setValue(0, animated: true)
        onResetAll?()
    }

    private static func makeToolButton(
        systemName: String,
        fallbackSystemName: String,
        accessibilityLabel: String
    ) -> UIButton {
        let button = UIButton(type: .system)

        let image = UIImage(systemName: systemName)
            ?? UIImage(systemName: fallbackSystemName)

        var configuration = UIButton.Configuration.plain()
        configuration.image = image
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: 18,
            weight: .medium
        )
        configuration.contentInsets = .zero

        button.configuration = configuration
        button.tintColor = .secondaryLabel
        button.layer.cornerRadius = 22

        button.accessibilityLabel = accessibilityLabel
        button.accessibilityHint = "Selects the \(accessibilityLabel.lowercased()) adjustment"

        return button
    }
}
