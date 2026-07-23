//
//  PresetPickerView.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 20.07.2026.
//

import UIKit
import SnapKit

final class PresetPickerView: UIView {

    var onPresetSelected: ((PhotoPreset) -> Void)?

    private let presets = PhotoPreset.allCases
    private var selectedPreset: PhotoPreset = .none

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()

        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.register(
            PresetCell.self,
            forCellWithReuseIdentifier: PresetCell.reuseIdentifier
        )

        return collectionView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setSelectedPreset(_ preset: PhotoPreset, animated: Bool) {
        selectedPreset = preset
        collectionView.reloadData()

        guard let index = presets.firstIndex(of: preset) else { return }

        collectionView.scrollToItem(
            at: IndexPath(item: index, section: 0),
            at: .centeredHorizontally,
            animated: animated
        )
    }

    private func setupLayout() {
        addSubview(collectionView)

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension PresetPickerView: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        presets.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PresetCell.reuseIdentifier,
            for: indexPath
        ) as? PresetCell else {
            return UICollectionViewCell()
        }

        let preset = presets[indexPath.item]

        cell.configure(
            title: preset.title,
            isSelected: preset == selectedPreset
        )

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let preset = presets[indexPath.item]

        guard preset != selectedPreset else { return }

        selectedPreset = preset
        collectionView.reloadData()

        onPresetSelected?(preset)
    }
}

private final class PresetCell: UICollectionViewCell {

    static let reuseIdentifier = "PresetCell"

    private let titleLabel: UILabel = {
        let label = UILabel()

        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center

        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(14)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(title: String, isSelected: Bool) {
        titleLabel.text = title

        contentView.backgroundColor = isSelected
            ? .systemBlue
            : .tertiarySystemBackground

        contentView.layer.borderColor = isSelected
            ? UIColor.systemBlue.cgColor
            : UIColor.separator.cgColor

        titleLabel.textColor = isSelected
            ? .white
            : .label
    }
}
