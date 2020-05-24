//
//  Document.swift
//  EmojiArt
//
//  Created by Alex Yatsenko on 24.05.2020.
//  Copyright © 2020 Alexislog's Production. All rights reserved.
//

import UIKit

class Document: UIDocument {
    
    override func contents(forType typeName: String) throws -> Any {
        // Encode your document with an instance of NSData or NSFileWrapper
        return Data()
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // Load your document from contents
    }
}

