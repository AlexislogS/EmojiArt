//
//  EmojiArt.swift
//  EmojiArt
//
//  Created by Alex Yatsenko on 23.05.2020.
//  Copyright © 2020 Alexislog's Production. All rights reserved.
//

import Foundation

struct EmojiArt: Codable {
    
    let url: URL
    var emojis = [EmojiInfo]()
    
    struct EmojiInfo: Codable {
        let x: Int
        let y: Int
        let text: String
        let size: Int
    }
    
    var json: Data? {
        return try? JSONEncoder().encode(self)
    }
    
    init(url: URL, emojis: [EmojiInfo]) {
        self.url = url
        self.emojis = emojis
    }
    
    init?(json: Data) {
        if let newValue = try? JSONDecoder().decode(EmojiArt.self, from: json) {
            self = newValue
        } else {
            return nil
        }
    }
}
