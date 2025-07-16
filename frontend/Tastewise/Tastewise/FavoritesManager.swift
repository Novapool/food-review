//
//  FavoritesManager.swift
//  Tastewise
//
//  Created by AI Assistant
//

import Foundation
import SwiftData

@Observable
class FavoritesManager {
    static let shared = FavoritesManager()
    
    private init() {}
    
    // Check if restaurant is favorited
    func isFavorite(_ restaurant: Restaurant, context: ModelContext) -> Bool {
        let predicate = #Predicate<UserFavorite> { favorite in
            favorite.placeId == restaurant.placeId
        }
        
        let descriptor = FetchDescriptor<UserFavorite>(predicate: predicate)
        
        do {
            let favorites = try context.fetch(descriptor)
            return !favorites.isEmpty
        } catch {
            print("Error checking favorite status: \(error)")
            return false
        }
    }
    
    // Toggle favorite status
    func toggleFavorite(_ restaurant: Restaurant, context: ModelContext) {
        if isFavorite(restaurant, context: context) {
            removeFavorite(restaurant, context: context)
        } else {
            addFavorite(restaurant, context: context)
        }
    }
    
    // Add to favorites
    func addFavorite(_ restaurant: Restaurant, context: ModelContext) {
        let favorite = UserFavorite(from: restaurant)
        context.insert(favorite)
        
        do {
            try context.save()
            print("✅ Added \(restaurant.name) to favorites")
        } catch {
            print("❌ Failed to add favorite: \(error)")
        }
    }
    
    // Remove from favorites
    func removeFavorite(_ restaurant: Restaurant, context: ModelContext) {
        let predicate = #Predicate<UserFavorite> { favorite in
            favorite.placeId == restaurant.placeId
        }
        
        let descriptor = FetchDescriptor<UserFavorite>(predicate: predicate)
        
        do {
            let favorites = try context.fetch(descriptor)
            if let favorite = favorites.first {
                context.delete(favorite)
                try context.save()
                print("✅ Removed \(restaurant.name) from favorites")
            }
        } catch {
            print("❌ Failed to remove favorite: \(error)")
        }
    }
    
    // Get all favorites
    func getAllFavorites(context: ModelContext) -> [UserFavorite] {
        let descriptor = FetchDescriptor<UserFavorite>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch favorites: \(error)")
            return []
        }
    }
}
