//
//  EditorFilmstripView.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 19.07.2026.
//

import UIKit
import SnapKit

final class EditorFilmstripView: UIView {

    var onPhotoSelected: ((Int) -> Void)?

    private var photos: [EditablePhoto] = []
    private var selectedIndex = 0

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 56, height: 56)
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(
            top: 6,
            left: 12,
            bottom: 6,
            right: 12
        )

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true

        collectionView.register(
            EditorFilmstripCell.self,
            forCellWithReuseIdentifier: EditorFilmstripCell.reuseIdentifier
        )

        return collectionView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .secondarySystemBackground

        setupLayout()

        collectionView.dataSource = self
        collectionView.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(
        photos: [EditablePhoto],
        selectedIndex: Int
    ) {
        self.photos = photos
        self.selectedIndex = selectedIndex

        collectionView.reloadData()

        DispatchQueue.main.async { [weak self] in
            self?.scrollToSelectedPhoto(animated: false)
        }
    }

    func setSelectedIndex(
        _ index: Int,
        animated: Bool
    ) {
        guard photos.indices.contains(index) else {
            return
        }

        let previousIndex = selectedIndex

        guard previousIndex != index else {
            scrollToSelectedPhoto(animated: animated)
            return
        }

        selectedIndex = index

        let indexPaths = [
            IndexPath(item: previousIndex, section: 0),
            IndexPath(item: index, section: 0)
        ]

        collectionView.reloadItems(at: indexPaths)
        scrollToSelectedPhoto(animated: animated)
    }

    private func setupLayout() {
        addSubview(collectionView)

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func scrollToSelectedPhoto(animated: Bool) {
        guard photos.indices.contains(selectedIndex) else {
            return
        }

        collectionView.scrollToItem(
            at: IndexPath(
                item: selectedIndex,
                section: 0
            ),
            at: .centeredHorizontally,
            animated: animated
        )
    }
}

extension EditorFilmstripView:
    UICollectionViewDataSource,
    UICollectionViewDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        photos.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: EditorFilmstripCell.reuseIdentifier,
            for: indexPath
        ) as? EditorFilmstripCell else {
            return UICollectionViewCell()
        }

        cell.configure(
            image: photos[indexPath.item].originalImage,
            isCurrent: indexPath.item == selectedIndex
        )

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        setSelectedIndex(
            indexPath.item,
            animated: true
        )

        onPhotoSelected?(indexPath.item)
    }
}

private final class EditorFilmstripCell: UICollectionViewCell {

    static let reuseIdentifier = "EditorFilmstripCell"

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(imageView)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        imageView.image = nil
        imageView.alpha = 1
        contentView.layer.borderWidth = 0
    }

    func configure(
        image: UIImage,
        isCurrent: Bool
    ) {
        imageView.image = image
        imageView.alpha = isCurrent ? 1 : 0.65

        contentView.layer.borderWidth = isCurrent ? 2 : 0
        contentView.layer.borderColor = UIColor.systemBlue.cgColor
    }
}
