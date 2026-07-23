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
        stackView.spacing = 8

        return stackView
    }()

    private let autoButton: UIButton = {
        let button = UIButton(type: .system)

        button.accessibilityLabel = "Auto"
        button.accessibilityHint = "Toggles automatic image adjustments"

        return button
    }()

    private let resetButton: UIButton = {
        let button = UIButton(type: .system)

        var configuration = UIButton.Configuration.bordered()
        configuration.title = "Reset"
        configuration.image = UIImage(systemName: "arrow.counterclockwise")
        configuration.imagePadding = 6

        button.configuration = configuration
        button.accessibilityLabel = "Reset photo"

        return button
    }()

    private let modeButton: UIButton = {
        let button = UIButton(type: .system)

        var configuration = UIButton.Configuration.plain()
        configuration.title = "Adjust"
        configuration.image = UIImage(systemName: "slider.horizontal.3")
        configuration.imagePadding = 8

        button.configuration = configuration
        button.accessibilityLabel = "Adjust photo"

        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground

        setupLayout()
        setupActions()
        updateAutoButtonAppearance()
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
        var configuration = modeButton.configuration ?? .plain()

        if showsAdjustments {
            configuration.title = "Styles"
            configuration.image = UIImage(systemName: "chevron.backward")
            modeButton.accessibilityLabel = "Return to styles"
        } else {
            configuration.title = "Adjust"
            configuration.image = UIImage(systemName: "slider.horizontal.3")
            modeButton.accessibilityLabel = "Adjust photo"
        }

        configuration.imagePadding = 8
        modeButton.configuration = configuration
    }

    private func setupLayout() {
        addSubview(leftButtonsStackView)
        addSubview(modeButton)

        leftButtonsStackView.addArrangedSubview(autoButton)
        leftButtonsStackView.addArrangedSubview(resetButton)

        leftButtonsStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(6)
        }

        modeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
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
        var configuration: UIButton.Configuration

        if autoButton.isSelected {
            configuration = .borderedProminent()
        } else {
            configuration = .bordered()
        }

        configuration.title = "Auto"
        configuration.image = UIImage(systemName: "wand.and.stars")
        configuration.imagePadding = 6

        autoButton.configuration = configuration
        autoButton.accessibilityValue = autoButton.isSelected ? "On" : "Off"

        if autoButton.isSelected {
            autoButton.accessibilityTraits.insert(.selected)
        } else {
            autoButton.accessibilityTraits.remove(.selected)
        }
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
