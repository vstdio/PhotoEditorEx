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
    var onShadowsChanged: ((Float) -> Void)?
    var onHighlightsChanged: ((Float) -> Void)?
    var onWhitesChanged: ((Float) -> Void)?
    var onBlacksChanged: ((Float) -> Void)?
    var onTemperatureChanged: ((Float) -> Void)?
    var onTintChanged: ((Float) -> Void)?
    var onVibranceChanged: ((Float) -> Void)?
    var onBlurChanged: ((Float) -> Void)?
    var onSharpenChanged: ((Float) -> Void)?
    var onVignetteChanged: ((Float) -> Void)?

    private let categorySegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(
            items: [
                "Tone",
                "Color",
                "Effects"
            ]
        )
        control.selectedSegmentIndex = 0
        return control
    }()

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
        value: 1,
        valueFormatter: {
            String(format: "%.0f", ($0 - 1) * 100)
        }
    )

    private let temperatureSliderView = AdjustmentSliderView(
        title: "Temperature",
        minimumValue: -1,
        maximumValue: 1,
        value: 0,
        valueFormatter: {
            String(format: "%.0f", $0 * 100)
        }
    )

    private let tintSliderView = AdjustmentSliderView(
        title: "Tint",
        minimumValue: -1,
        maximumValue: 1,
        value: 0,
        valueFormatter: {
            String(format: "%.0f", $0 * 100)
        }
    )

    private let vibranceSliderView = AdjustmentSliderView(
        title: "Vibrance",
        minimumValue: -1,
        maximumValue: 1,
        value: 0,
        valueFormatter: {
            String(format: "%.0f", $0 * 100)
        }
    )

    private let exposureSliderView = AdjustmentSliderView(
        title: "Exposure",
        minimumValue: -2,
        maximumValue: 2,
        value: 0
    )

    private let shadowsSliderView = AdjustmentSliderView(
        title: "Shadows",
        minimumValue: -1,
        maximumValue: 1,
        value: 0,
        valueFormatter: {
            String(format: "%.0f", $0 * 100)
        }
    )

    private let highlightsSliderView = AdjustmentSliderView(
        title: "Highlights",
        minimumValue: -1,
        maximumValue: 1,
        value: 0,
        valueFormatter: {
            String(format: "%.0f", $0 * 100)
        }
    )

    private let whitesSliderView = AdjustmentSliderView(
        title: "Whites",
        minimumValue: -1,
        maximumValue: 1,
        value: 0,
        valueFormatter: {
            String(format: "%.0f", $0 * 100)
        }
    )

    private let blacksSliderView = AdjustmentSliderView(
        title: "Blacks",
        minimumValue: -1,
        maximumValue: 1,
        value: 0,
        valueFormatter: {
            String(format: "%.0f", $0 * 100)
        }
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

    private let toolsContentView = UIView()

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

    private let temperatureToolButton = EditorControlsView.makeToolButton(
        systemName: "thermometer.medium",
        fallbackSystemName: "thermometer",
        accessibilityLabel: "Temperature"
    )

    private let tintToolButton = EditorControlsView.makeToolButton(
        systemName: "eyedropper.halffull",
        fallbackSystemName: "eyedropper",
        accessibilityLabel: "Tint"
    )

    private let vibranceToolButton = EditorControlsView.makeToolButton(
        systemName: "sparkles",
        fallbackSystemName: "wand.and.stars",
        accessibilityLabel: "Vibrance"
    )

    private let exposureToolButton = EditorControlsView.makeToolButton(
        systemName: "plusminus.circle.fill",
        fallbackSystemName: "plusminus.circle",
        accessibilityLabel: "Exposure"
    )

    private let shadowsToolButton = EditorControlsView.makeToolButton(
        systemName: "circle.bottomhalf.filled",
        fallbackSystemName: "circle.lefthalf.filled",
        accessibilityLabel: "Shadows"
    )

    private let highlightsToolButton = EditorControlsView.makeToolButton(
        systemName: "circle.tophalf.filled",
        fallbackSystemName: "sun.max.fill",
        accessibilityLabel: "Highlights"
    )

    private let whitesToolButton = EditorControlsView.makeToolButton(
        systemName: "circle",
        fallbackSystemName: "circle.fill",
        accessibilityLabel: "Whites"
    )

    private let blacksToolButton = EditorControlsView.makeToolButton(
        systemName: "circle.fill",
        fallbackSystemName: "circle",
        accessibilityLabel: "Blacks"
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

    private var activeSliderView: AdjustmentSliderView?
    private var selectedToolButton: UIButton?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        setupLayout()
        setupActions()
        showToneCategory()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setRecipe(
        _ recipe: EditRecipe,
        animated: Bool
    ) {
        brightnessSliderView.setValue(
            recipe.brightness,
            animated: animated
        )

        contrastSliderView.setValue(
            recipe.contrast,
            animated: animated
        )

        exposureSliderView.setValue(
            recipe.exposure,
            animated: animated
        )

        shadowsSliderView.setValue(
            recipe.shadows,
            animated: animated
        )

        highlightsSliderView.setValue(
            recipe.highlights,
            animated: animated
        )

        whitesSliderView.setValue(
            recipe.whites,
            animated: animated
        )

        blacksSliderView.setValue(
            recipe.blacks,
            animated: animated
        )

        temperatureSliderView.setValue(
            recipe.temperature,
            animated: animated
        )

        tintSliderView.setValue(
            recipe.tint,
            animated: animated
        )

        vibranceSliderView.setValue(
            recipe.vibrance,
            animated: animated
        )

        saturationSliderView.setValue(
            recipe.saturation,
            animated: animated
        )

        sharpenSliderView.setValue(
            recipe.sharpen,
            animated: animated
        )

        blurSliderView.setValue(
            recipe.blurRadius,
            animated: animated
        )

        vignetteSliderView.setValue(
            recipe.vignette,
            animated: animated
        )
    }

    private func setupLayout() {
        addSubview(categorySegmentedControl)
        addSubview(activeSliderContainerView)
        addSubview(toolsScrollView)

        toolsScrollView.addSubview(toolsContentView)
        toolsContentView.addSubview(toolsStackView)

        categorySegmentedControl.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(36)
        }

        activeSliderContainerView.snp.makeConstraints { make in
            make.top.equalTo(categorySegmentedControl.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(64)
        }

        toolsScrollView.snp.makeConstraints { make in
            make.top.equalTo(activeSliderContainerView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(44)
            make.bottom.equalToSuperview().inset(16)
        }

        toolsContentView.snp.makeConstraints { make in
            make.edges.equalTo(toolsScrollView.contentLayoutGuide)
            make.height.equalTo(toolsScrollView.frameLayoutGuide)

            make.width.greaterThanOrEqualTo(
                toolsScrollView.frameLayoutGuide
            )

            make.width.equalTo(
                toolsScrollView.frameLayoutGuide
            ).priority(750)
        }

        toolsStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
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

        temperatureSliderView.onValueChanged = { [weak self] value in
            self?.onTemperatureChanged?(value)
        }

        tintSliderView.onValueChanged = { [weak self] value in
            self?.onTintChanged?(value)
        }

        vibranceSliderView.onValueChanged = { [weak self] value in
            self?.onVibranceChanged?(value)
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

        shadowsSliderView.onValueChanged = { [weak self] value in
            self?.onShadowsChanged?(value)
        }

        highlightsSliderView.onValueChanged = { [weak self] value in
            self?.onHighlightsChanged?(value)
        }

        whitesSliderView.onValueChanged = { [weak self] value in
            self?.onWhitesChanged?(value)
        }

        blacksSliderView.onValueChanged = { [weak self] value in
            self?.onBlacksChanged?(value)
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

        temperatureToolButton.addTarget(
            self,
            action: #selector(temperatureToolButtonTapped),
            for: .touchUpInside
        )

        tintToolButton.addTarget(
            self,
            action: #selector(tintToolButtonTapped),
            for: .touchUpInside
        )

        vibranceToolButton.addTarget(
            self,
            action: #selector(vibranceToolButtonTapped),
            for: .touchUpInside
        )

        exposureToolButton.addTarget(
            self,
            action: #selector(exposureToolButtonTapped),
            for: .touchUpInside
        )

        shadowsToolButton.addTarget(
            self,
            action: #selector(shadowsToolButtonTapped),
            for: .touchUpInside
        )

        highlightsToolButton.addTarget(
            self,
            action: #selector(highlightsToolButtonTapped),
            for: .touchUpInside
        )

        whitesToolButton.addTarget(
            self,
            action: #selector(whitesToolButtonTapped),
            for: .touchUpInside
        )

        blacksToolButton.addTarget(
            self,
            action: #selector(blacksToolButtonTapped),
            for: .touchUpInside
        )

        categorySegmentedControl.addTarget(
            self,
            action: #selector(categoryChanged),
            for: .valueChanged
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
    }

    @objc private func categoryChanged() {
        switch categorySegmentedControl.selectedSegmentIndex {
        case 0:
            showToneCategory()

        case 1:
            showColorCategory()

        case 2:
            showEffectsCategory()

        default:
            break
        }
    }

    private func showToneCategory() {
        removeToolButtons()

        toolsStackView.addArrangedSubview(exposureToolButton)
        toolsStackView.addArrangedSubview(brightnessToolButton)
        toolsStackView.addArrangedSubview(contrastToolButton)
        toolsStackView.addArrangedSubview(shadowsToolButton)
        toolsStackView.addArrangedSubview(highlightsToolButton)
        toolsStackView.addArrangedSubview(whitesToolButton)
        toolsStackView.addArrangedSubview(blacksToolButton)

        showAdjustment(
            exposureSliderView,
            selectedButton: exposureToolButton
        )
    }

    private func showColorCategory() {
        removeToolButtons()

        toolsStackView.addArrangedSubview(temperatureToolButton)
        toolsStackView.addArrangedSubview(tintToolButton)
        toolsStackView.addArrangedSubview(vibranceToolButton)
        toolsStackView.addArrangedSubview(saturationToolButton)

        showAdjustment(
            temperatureSliderView,
            selectedButton: temperatureToolButton
        )
    }

    private func showEffectsCategory() {
        removeToolButtons()

        toolsStackView.addArrangedSubview(sharpenToolButton)
        toolsStackView.addArrangedSubview(blurToolButton)
        toolsStackView.addArrangedSubview(vignetteToolButton)

        showAdjustment(
            sharpenSliderView,
            selectedButton: sharpenToolButton
        )
    }

    private func removeToolButtons() {
        toolsStackView.arrangedSubviews.forEach { view in
            toolsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
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

    @objc private func shadowsToolButtonTapped() {
        showAdjustment(
            shadowsSliderView,
            selectedButton: shadowsToolButton
        )
    }

    @objc private func highlightsToolButtonTapped() {
        showAdjustment(
            highlightsSliderView,
            selectedButton: highlightsToolButton
        )
    }

    @objc private func whitesToolButtonTapped() {
        showAdjustment(
            whitesSliderView,
            selectedButton: whitesToolButton
        )
    }

    @objc private func blacksToolButtonTapped() {
        showAdjustment(
            blacksSliderView,
            selectedButton: blacksToolButton
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

    @objc private func temperatureToolButtonTapped() {
        showAdjustment(
            temperatureSliderView,
            selectedButton: temperatureToolButton
        )
    }

    @objc private func tintToolButtonTapped() {
        showAdjustment(
            tintSliderView,
            selectedButton: tintToolButton
        )
    }

    @objc private func vibranceToolButtonTapped() {
        showAdjustment(
            vibranceSliderView,
            selectedButton: vibranceToolButton
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

        button.snp.makeConstraints { make in
            make.width.height.equalTo(44)
        }

        return button
    }
}
