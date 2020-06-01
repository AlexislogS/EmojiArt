//
//  DocumentInfoViewController.swift
//  EmojiArt
//
//  Created by Alex Yatsenko on 31.05.2020.
//  Copyright © 2020 Alexislog's Production. All rights reserved.
//

import UIKit

final class DocumentInfoViewController: UIViewController {
    
    var document: EmojiArtDocument? {
        didSet { updateUI() }
    }
    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    @IBOutlet private weak var topLevelView: UIStackView!
    @IBOutlet private weak var sizeLabel: UILabel!
    @IBOutlet private weak var createdLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        calculatePopOver()
    }
    
    private func updateUI() {
        if sizeLabel != nil, createdLabel != nil,
            let url = document?.fileURL,
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            sizeLabel.text = "Size: \(attributes[.size] ?? 0) bytes"
            if let created = attributes[.creationDate] as? Date {
                createdLabel.text = "Created: \(shortDateFormatter.string(from: created))"
            }
        }
        if popoverPresentationController != nil {
            view.backgroundColor = .clear
        }
    }
    
    private func calculatePopOver() {
        let gapForView: CGFloat = 30
        if let fittedSize = topLevelView?.sizeThatFits(UIView.layoutFittingCompressedSize) {
            preferredContentSize = CGSize(width: fittedSize.width + gapForView,
                                          height: fittedSize.height + gapForView)
        }
    }
    
}
