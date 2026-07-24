//
//  PhotoMetadataViewController.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 24.07.2026.
//

import UIKit
import SnapKit

final class PhotoMetadataViewController: UIViewController {

    private static let sectionHeaderReuseIdentifier = "PhotoMetadataSectionHeader"

    private let metadata: PhotoMetadata

    private let tableView: UITableView = {
        let tableView = UITableView(
            frame: .zero,
            style: .insetGrouped
        )

        tableView.backgroundColor = .systemGroupedBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64

        return tableView
    }()

    init(metadata: PhotoMetadata) {
        self.metadata = metadata

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Photo Info"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeButtonTapped)
        )

        tableView.dataSource = self
        tableView.delegate = self

        tableView.register(
            PhotoMetadataCell.self,
            forCellReuseIdentifier: PhotoMetadataCell.reuseIdentifier
        )

        tableView.register(
            UITableViewHeaderFooterView.self,
            forHeaderFooterViewReuseIdentifier: Self.sectionHeaderReuseIdentifier
        )

        view.addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}

extension PhotoMetadataViewController: UITableViewDataSource {

    func numberOfSections(
        in tableView: UITableView
    ) -> Int {
        metadata.sections.count
    }

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        metadata.sections[section].rows.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: PhotoMetadataCell.reuseIdentifier,
            for: indexPath
        ) as? PhotoMetadataCell else {
            return UITableViewCell()
        }

        let row = metadata
            .sections[indexPath.section]
            .rows[indexPath.row]

        cell.configure(
            title: row.title,
            value: row.value
        )

        return cell
    }
}

extension PhotoMetadataViewController: UITableViewDelegate {

    func tableView(
        _ tableView: UITableView,
        viewForHeaderInSection section: Int
    ) -> UIView? {
        let section = metadata.sections[section]

        guard let headerView = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: Self.sectionHeaderReuseIdentifier
        ) else {
            return nil
        }

        var configuration = UIListContentConfiguration.groupedHeader()

        configuration.text = section.title.uppercased()
        configuration.image = UIImage(systemName: section.iconName)
        configuration.imageToTextPadding = 8

        configuration.textProperties.font = .systemFont(
            ofSize: 16,
            weight: .semibold
        )

        configuration.textProperties.color = .label
        configuration.imageProperties.tintColor = .systemBlue

        configuration.imageProperties.preferredSymbolConfiguration =
            UIImage.SymbolConfiguration(
                pointSize: 16,
                weight: .semibold
            )

        headerView.contentConfiguration = configuration

        return headerView
    }

    func tableView(
        _ tableView: UITableView,
        heightForHeaderInSection section: Int
    ) -> CGFloat {
        44
    }
}

private final class PhotoMetadataCell: UITableViewCell {

    static let reuseIdentifier = "PhotoMetadataCell"

    private let titleLabel: UILabel = {
        let label = UILabel()

        label.font = .preferredFont(
            forTextStyle: .caption1
        )

        label.textColor = .secondaryLabel

        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()

        label.font = .preferredFont(
            forTextStyle: .body
        )

        label.textColor = .label
        label.numberOfLines = 0

        return label
    }()

    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(
            style: style,
            reuseIdentifier: reuseIdentifier
        )

        selectionStyle = .none

        let stackView = UIStackView(
            arrangedSubviews: [
                titleLabel,
                valueLabel
            ]
        )

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 4

        contentView.addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(
                contentView.layoutMarginsGuide
            )
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(
        title: String,
        value: String
    ) {
        titleLabel.text = title
        valueLabel.text = value
    }
}
