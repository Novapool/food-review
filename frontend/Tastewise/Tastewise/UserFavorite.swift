//
//  UserFavorite.swift
//  Tastewise
//
//  Created by AI Assistant
//

import Foundation
import SwiftData

@Model
final class UserFavorite {
    @Attribute(.unique) var placeId: String
    var restaurantName: String
    var restaurantAddress: String
    var createdAt: Date
    
    init(placeId: String, restaurantName: String, restaurantAddress: String) {
        self.placeId = placeId
        self.restaurantName = restaurantName
        self.restaurantAddress = restaurantAddress
        self.createdAt = Date()
    }
    
    // Convenience initializer from Restaurant
    convenience init(from restaurant: Restaurant) {
        self.init(
            placeId: restaurant.placeId,
            restaurantName: restaurant.name,
            restaurantAddress: restaurant.address
        )
    }
}
