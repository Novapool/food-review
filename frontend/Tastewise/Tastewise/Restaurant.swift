//
//  Restaurant.swift
//  Tastewise
//
//  Created by Laith Assaf on 1/5/25.
//

import Foundation
import SwiftData

// MARK: - Restaurant Data Models

@Model
final class Restaurant {
    var placeId: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var rating: Double?
    var totalRatings: Int?
    var priceLevel: Int?
    var cuisineTypes: [String]
    var phone: String?
    var website: String?
    var photos: [String]
    var distanceMiles: Double?
    var isRecommended: Bool
    var isPopular: Bool
    var createdAt: Date
    
    init(
        placeId: String,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        rating: Double? = nil,
        totalRatings: Int? = nil,
        priceLevel: Int? = nil,
        cuisineTypes: [String] = [],
        phone: String? = nil,
        website: String? = nil,
        photos: [String] = [],
        distanceMiles: Double? = nil,
        isRecommended: Bool = false,
        isPopular: Bool = false
    ) {
        self.placeId = placeId
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.rating = rating
        self.totalRatings = totalRatings
        self.priceLevel = priceLevel
        self.cuisineTypes = cuisineTypes
        self.phone = phone
        self.website = website
        self.photos = photos
        self.distanceMiles = distanceMiles
        self.isRecommended = isRecommended
        self.isPopular = isPopular
        self.createdAt = Date()
    }
}

// MARK: - API Response Models

struct RestaurantSearchResponse: Codable {
    let restaurants: [RestaurantAPI]
    let totalFound: Int
    let searchLocation: SearchLocation
    let radiusMiles: Double
    let timestamp: String
}

struct RestaurantAPI: Codable {
    let placeId: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let rating: Double?
    let totalRatings: Int?
    let priceLevel: Int?
    let cuisineTypes: [String]
    let phone: String?
    let website: String?
    let photos: [String]
    let distanceMiles: Double?
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name, address, latitude, longitude, rating
        case totalRatings = "total_ratings"
        case priceLevel = "price_level"
        case cuisineTypes = "cuisine_types"
        case phone, website, photos
        case distanceMiles = "distance_miles"
    }
}

struct SearchLocation: Codable {
    let lat: Double
    let lng: Double
}

// MARK: - Filter and Sort Options

enum RestaurantSortOption: String, CaseIterable {
    case nearby = "Nearby"
    case recommended = "Recommended"
    case topRated = "Top Rated"
    case priceLow = "Price: Low"
    case priceHigh = "Price: High"
    case mostReviewed = "Most Reviewed"
    
    var displayName: String {
        return self.rawValue
    }
}

enum CuisineFilter: String, CaseIterable {
    case all = "All"
    case pizza = "Pizza"
    case burgers = "Burgers"
    case asian = "Asian"
    case healthy = "Healthy"
    case italian = "Italian"
    case mexican = "Mexican"
    case fastFood = "Fast Food"
    
    var emoji: String {
        switch self {
        case .all: return "🍽️"
        case .pizza: return "🍕"
        case .burgers: return "🍔"
        case .asian: return "🍜"
        case .healthy: return "🥗"
        case .italian: return "🍝"
        case .mexican: return "🌮"
        case .fastFood: return "🍟"
        }
    }
    
    var displayName: String {
        return "\(emoji) \(rawValue)"
    }
}

// MARK: - Restaurant Extensions

extension Restaurant {
    var formattedRating: String {
        guard let rating = rating else { return "No rating" }
        return String(format: "%.1f", rating)
    }
    
    var formattedDistance: String {
        guard let distance = distanceMiles else { return "" }
        return String(format: "%.1f mi", distance)
    }
    
    var priceDisplay: String {
        guard let priceLevel = priceLevel else { return "" }
        return String(repeating: "$", count: min(priceLevel, 4))
    }
    
    var ratingStars: String {
        guard let rating = rating else { return "" }
        let fullStars = Int(rating)
        let hasHalfStar = rating - Double(fullStars) >= 0.5
        
        var stars = String(repeating: "⭐", count: fullStars)
        if hasHalfStar && fullStars < 5 {
            stars += "⭐" // Using full star for simplicity, could use half star emoji
        }
        return stars
    }
    
    var primaryCuisine: String {
        return cuisineTypes.first?.capitalized ?? "Restaurant"
    }
    
    var badgeText: String? {
        if isRecommended {
            return "AI Recommended"
        } else if isPopular {
            return "Popular"
        }
        return nil
    }
    
    var badgeColor: String {
        if isRecommended {
            return "purple"
        } else if isPopular {
            return "red"
        }
        return "gray"
    }
}

extension RestaurantAPI {
    func toRestaurant(isRecommended: Bool = false, isPopular: Bool = false) -> Restaurant {
        return Restaurant(
            placeId: placeId,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            rating: rating,
            totalRatings: totalRatings,
            priceLevel: priceLevel,
            cuisineTypes: cuisineTypes,
            phone: phone,
            website: website,
            photos: photos,
            distanceMiles: distanceMiles,
            isRecommended: isRecommended,
            isPopular: isPopular
        )
    }
}
