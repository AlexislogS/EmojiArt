//
//  ImageFetcherManager.swift
//  EmojiArt
//
//  Created by Alex Yatsenko on 09.05.2020.
//  Copyright © 2020 Alexislog's Production. All rights reserved.
//

import UIKit

final class ImageFetcherManager {
    
    var backupImage: UIImage? { didSet { callHandlerIfNeeded() } }
    
    private let handler: (URL, UIImage) -> Void
    private var fetchFailed = false { didSet { callHandlerIfNeeded() } }
    
    init(handler: @escaping (URL, UIImage) -> Void) {
        self.handler = handler
    }
    
    init(fetch url: URL, handler: @escaping (URL, UIImage) -> Void) {
        self.handler = handler
        fetch(url)
    }
    
    private func callHandlerIfNeeded() {
        if fetchFailed, let image = backupImage, let url = image.storeLocallyAsJPEG(named: String(Date().timeIntervalSinceReferenceDate)) {
            handler(url, image)
        }
    }
    
    func fetch(_ url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let data = try? Data(contentsOf: url) {
                guard self != nil else { return print("ImageFetcherManager left the heap") }
                if let image = UIImage(data: data) {
                    self?.handler(url, image)
                }
            } else {
                self?.fetchFailed = true
            }
        }
    }
    
}

