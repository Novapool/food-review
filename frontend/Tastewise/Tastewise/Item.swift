//
//  Item.swift
//  Tastewise
//
//  Created by Laith Assaf on 1/5/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
