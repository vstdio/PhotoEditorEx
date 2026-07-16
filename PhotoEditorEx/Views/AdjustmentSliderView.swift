//
//  AdjustmentSliderView.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 13.07.2026.
//

import UIKit
import SnapKit

final class AdjustmentSliderView: UIView {

    var onValueChanged: ((Float) -> Void)?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()

    private let slider: UISlider = {
        let slider = UISlider()
        return slider
    }()

    private let valueFormatter: (Float) -> String

    init(
        title: String,
        minimumValue: Float,
        maximumValue: Float,
        value: Float,
        valueFormatter: @escaping (Float) -> String = { String(format: "%.2f", $0) }
    ) {
        self.valueFormatter = valueFormatter

        super.init(frame: .zero)

        titleLabel.text = title

        slider.minimumValue = minimumValue
        slider.maximumValue = maximumValue
        slider.value = value

        valueLabel.text = valueFormatter(value)

        setupLayout()
        setupActions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setValue(_ value: Float, animated: Bool) {
        slider.setValue(value, animated: animated)
        valueLabel.text = valueFormatter(value)
    }

    func currentValue() -> Float {
        slider.value
    }

    private func setupLayout() {
        let headerStackView = UIStackView(arrangedSubviews: [
            titleLabel,
            valueLabel
        ])

        headerStackView.axis = .horizontal
        headerStackView.alignment = .center
        headerStackView.distribution = .equalSpacing
        headerStackView.spacing = 12

        addSubview(headerStackView)
        addSubview(slider)

        headerStackView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        valueLabel.snp.makeConstraints { make in
            make.width.equalTo(70)
        }

        slider.snp.makeConstraints { make in
            make.top.equalTo(headerStackView.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupActions() {
        slider.addTarget(
            self,
            action: #selector(sliderValueChanged),
            for: .valueChanged
        )
    }

    @objc private func sliderValueChanged() {
        let value = slider.value
        valueLabel.text = valueFormatter(value)
        onValueChanged?(value)
    }
}
