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

    @IBOutlet private weak var thumbnailImageView: UIImageView!
    @IBOutlet private weak var sizeLabel: UILabel!
    @IBOutlet private weak var createdLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }
    
    @IBAction private func done() {
        presentingViewController?.dismiss(animated: true)
    }
    
    private func updateUI() {
        if sizeLabel != nil, createdLabel != nil,
            let url = document?.fileURL,
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            sizeLabel.text = "\(attributes[.size] ?? 0 ) bytes"
            if let created = attributes[.creationDate] as? Date {
                createdLabel.text = shortDateFormatter.string(from: created)
            }
        }
        if thumbnailImageView != nil, let thumbnail = document?.thumbnail {
            thumbnailImageView.image = thumbnail
        }
    }
    
}
