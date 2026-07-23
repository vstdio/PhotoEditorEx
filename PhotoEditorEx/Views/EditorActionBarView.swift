//
//  EditorActionBarView.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 23.07.2026.
//

import UIKit
import SnapKit

final class EditorActionBarView: UIView {

    var onAutoTapped: ((Bool) -> Void)?
    var onResetTapped: (() -> Void)?
    var onModeTapped: (() -> Void)?

    private let leftButtonsStackView: UIStackView = {
        let stackView = UIStackView()

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 0

        return stackView
    }()

    private let autoButton = UIButton(type: .system)
    private let resetButton = UIButton(type: .system)
    private let modeButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground

        setupButtons()
        setupLayout()
        setupActions()
        updateAutoButtonAppearance()
        setShowsAdjustments(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setAutoEnabled(_ isEnabled: Bool) {
        autoButton.isSelected = isEnabled
        updateAutoButtonAppearance()
    }

    func setShowsAdjustments(_ showsAdjustments: Bool) {
        modeButton.configuration = makeButtonConfiguration(
            title: showsAdjustments ? "Styles" : "Adjust",
            imageName: showsAdjustments ? "chevron.left" : "slider.horizontal.3",
            color: .systemBlue
        )

        modeButton.accessibilityLabel = showsAdjustments
            ? "Return to styles"
            : "Adjust photo"
    }

    private func setupButtons() {
        resetButton.configuration = makeButtonConfiguration(
            title: "Reset",
            imageName: "arrow.counterclockwise",
            color: .secondaryLabel
        )

        autoButton.accessibilityLabel = "Auto"
        autoButton.accessibilityHint = "Toggles automatic image adjustments"

        resetButton.accessibilityLabel = "Reset photo"

        [autoButton, resetButton, modeButton].forEach { button in
            button.configurationUpdateHandler = { button in
                if !button.isEnabled {
                    button.alpha = 0.35
                } else if button.isHighlighted {
                    button.alpha = 0.5
                } else {
                    button.alpha = 1
                }
            }
        }
    }

    private func setupLayout() {
        addSubview(leftButtonsStackView)
        addSubview(modeButton)

        leftButtonsStackView.addArrangedSubview(autoButton)
        leftButtonsStackView.addArrangedSubview(resetButton)

        leftButtonsStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(4)
            make.leading.equalToSuperview().offset(8)
        }

        modeButton.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(4)
            make.trailing.equalToSuperview().inset(8)
            make.leading.greaterThanOrEqualTo(leftButtonsStackView.snp.trailing).offset(16)
        }

        modeButton.setContentHuggingPriority(.required, for: .horizontal)
        modeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func setupActions() {
        autoButton.addTarget(self, action: #selector(autoButtonTapped), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        modeButton.addTarget(self, action: #selector(modeButtonTapped), for: .touchUpInside)
    }

    private func updateAutoButtonAppearance() {
        autoButton.configuration = makeButtonConfiguration(
            title: "Auto",
            imageName: autoButton.isSelected ? "checkmark.circle.fill" : "wand.and.stars",
            color: autoButton.isSelected ? .systemBlue : .label
        )

        autoButton.accessibilityValue = autoButton.isSelected ? "On" : "Off"

        if autoButton.isSelected {
            autoButton.accessibilityTraits.insert(.selected)
        } else {
            autoButton.accessibilityTraits.remove(.selected)
        }
    }

    private func makeButtonConfiguration(
        title: String,
        imageName: String,
        color: UIColor
    ) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()

        configuration.title = title
        configuration.image = UIImage(systemName: imageName)
        configuration.imagePadding = 6
        configuration.baseForegroundColor = color
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 8,
            bottom: 0,
            trailing: 8
        )

        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var attributes = $0
            attributes.font = .systemFont(ofSize: 14, weight: .medium)
            return attributes
        }

        return configuration
    }

    @objc private func autoButtonTapped() {
        let isEnabled = !autoButton.isSelected

        setAutoEnabled(isEnabled)
        onAutoTapped?(isEnabled)
    }

    @objc private func resetButtonTapped() {
        onResetTapped?()
    }

    @objc private func modeButtonTapped() {
        onModeTapped?()
    }
}
