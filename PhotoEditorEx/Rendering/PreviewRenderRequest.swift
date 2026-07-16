//
//  PreviewRenderRequest.swift
//  PhotoEditorEx
//
//  Created by Timur Karimov on 16.07.2026.
//

import UIKit

final class PreviewRenderRequest {

    let id = UUID()

    private(set) lazy var workItem = DispatchWorkItem { [weak self] in
        self?.execute()
    }

    var isCancelled: Bool {
        workItem.isCancelled
    }

    private let render: () -> UIImage?
    private let completion: (UUID, UIImage?) -> Void

    init(
        render: @escaping () -> UIImage?,
        completion: @escaping (UUID, UIImage?) -> Void
    ) {
        self.render = render
        self.completion = completion
    }

    func cancel() {
        workItem.cancel()
    }

    private func execute() {
        guard !isCancelled else {
            return
        }

        let renderedImage = render()

        guard !isCancelled else {
            return
        }

        completion(id, renderedImage)
    }
}
