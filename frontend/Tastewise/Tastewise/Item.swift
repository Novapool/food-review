//
//  Item.swift
//  Tastewise
//
//  Created by Laith Assaf on 6/24/25.
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
