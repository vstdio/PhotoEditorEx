//
//  EditorImageView.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 17.07.2026.
//

import UIKit
import SnapKit

final class EditorImageView: UIView {

    var image: UIImage? {
        get {
            imageView.image
        }
        set {
            let imageSizeChanged = imageView.image?.size != newValue?.size

            imageView.image = newValue

            if imageSizeChanged {
                setNeedsLayout()
            }
        }
    }

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()

        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        return scrollView
    }()

    private let imageView: UIImageView = {
        let imageView = UIImageView()

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true

        return imageView
    }()

    private var lastLayoutSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .secondarySystemBackground

        setupLayout()
        setupActions()

        scrollView.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let currentSize = scrollView.bounds.size

        guard currentSize.width > 0,
              currentSize.height > 0 else {
            return
        }

        guard lastLayoutSize != currentSize else {
            updateContentInset()
            return
        }

        lastLayoutSize = currentSize
        configureImageFrame()
    }

    func resetZoom(animated: Bool) {
        scrollView.setZoomScale(
            scrollView.minimumZoomScale,
            animated: animated
        )
    }

    private func setupLayout() {
        addSubview(scrollView)
        scrollView.addSubview(imageView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupActions() {
        let doubleTapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDoubleTap)
        )

        doubleTapGestureRecognizer.numberOfTapsRequired = 2

        imageView.addGestureRecognizer(doubleTapGestureRecognizer)
    }

    private func configureImageFrame() {
        guard let image else {
            imageView.frame = .zero
            scrollView.contentSize = .zero
            return
        }

        scrollView.setZoomScale(
            scrollView.minimumZoomScale,
            animated: false
        )

        let availableSize = scrollView.bounds.size
        let imageSize = image.size

        guard imageSize.width > 0,
              imageSize.height > 0 else {
            return
        }

        let horizontalScale = availableSize.width / imageSize.width
        let verticalScale = availableSize.height / imageSize.height
        let aspectFitScale = min(horizontalScale, verticalScale)

        let fittedSize = CGSize(
            width: imageSize.width * aspectFitScale,
            height: imageSize.height * aspectFitScale
        )

        imageView.frame = CGRect(
            origin: .zero,
            size: fittedSize
        )

        scrollView.contentSize = fittedSize

        updateContentInset()
    }

    private func updateContentInset() {
        let horizontalInset = max(
            (scrollView.bounds.width - scrollView.contentSize.width) / 2,
            0
        )

        let verticalInset = max(
            (scrollView.bounds.height - scrollView.contentSize.height) / 2,
            0
        )

        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    @objc private func handleDoubleTap(
        _ gestureRecognizer: UITapGestureRecognizer
    ) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            resetZoom(animated: true)
            return
        }

        let targetZoomScale = min(
            2.5,
            scrollView.maximumZoomScale
        )

        let tapLocation = gestureRecognizer.location(in: imageView)

        let zoomRectSize = CGSize(
            width: scrollView.bounds.width / targetZoomScale,
            height: scrollView.bounds.height / targetZoomScale
        )

        let zoomRect = CGRect(
            x: tapLocation.x - zoomRectSize.width / 2,
            y: tapLocation.y - zoomRectSize.height / 2,
            width: zoomRectSize.width,
            height: zoomRectSize.height
        )

        scrollView.zoom(
            to: zoomRect,
            animated: true
        )
    }
}

extension EditorImageView: UIScrollViewDelegate {

    func viewForZooming(
        in scrollView: UIScrollView
    ) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(
        _ scrollView: UIScrollView
    ) {
        updateContentInset()
    }
}
