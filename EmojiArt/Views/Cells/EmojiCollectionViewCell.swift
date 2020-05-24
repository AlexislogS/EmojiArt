//
//  EmojiCollectionViewCell.swift
//  EmojiArt
//
//  Created by Alex Yatsenko on 11.05.2020.
//  Copyright © 2020 Alexislog's Production. All rights reserved.
//

import UIKit

final class EmojiCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet private(set) weak var label: UILabel!
    
    func configure(with emoji: String) {
        label.attributedText = emoji.attributedString(withTextStyle: .body, ofSize: 64)
    }
}
