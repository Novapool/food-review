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
    var lastSeen: Date
    var searchCount: Int
    var cacheLocations: [String]
    
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
        self.lastSeen = Date()
        self.searchCount = 0
        self.cacheLocations = []
    }
}

// MARK: - API Response Models

struct RestaurantSearchResponse: Codable {
    let success: Bool?
    let restaurants: [RestaurantAPI]
    let totalFound: Int?
    let searchLocation: SearchLocation?
    let radiusMiles: Double?
    let timestamp: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case restaurants
        case totalFound = "total_found"
        case searchLocation = "search_location"
        case radiusMiles = "radius_miles"
        case timestamp
        case message
    }
    
    // Custom initializer to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle success field (may be missing)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        
        // Required field
        restaurants = try container.decode([RestaurantAPI].self, forKey: .restaurants)
        
        // Optional fields
        totalFound = try container.decodeIfPresent(Int.self, forKey: .totalFound)
        searchLocation = try container.decodeIfPresent(SearchLocation.self, forKey: .searchLocation)
        radiusMiles = try container.decodeIfPresent(Double.self, forKey: .radiusMiles)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
    
    // Custom initializer for creating from cache results
    init(
        success: Bool? = true,
        restaurants: [RestaurantAPI],
        totalFound: Int? = nil,
        searchLocation: SearchLocation? = nil,
        radiusMiles: Double? = nil,
        timestamp: String? = nil,
        message: String? = nil
    ) {
        self.success = success
        self.restaurants = restaurants
        self.totalFound = totalFound
        self.searchLocation = searchLocation
        self.radiusMiles = radiusMiles
        self.timestamp = timestamp
        self.message = message
    }
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
    let isOpen: Bool?
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case address = "formatted_address"  // ✅ Fixed: Map to formatted_address
        case latitude
        case longitude
        case rating
        case totalRatings = "total_ratings"
        case priceLevel = "price_level"
        case cuisineTypes = "cuisine_types"
        case phone
        case website
        case photos
        case distanceMiles = "distance_miles"
        case isOpen = "is_open"
    }
    
    // Custom initializer for flexible parsing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        placeId = try container.decode(String.self, forKey: .placeId)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        
        // Address handling - the CodingKey is already mapped to formatted_address
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? "Address not available"
        
        // Optional fields with safe defaults
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        totalRatings = try container.decodeIfPresent(Int.self, forKey: .totalRatings)
        priceLevel = try container.decodeIfPresent(Int.self, forKey: .priceLevel)
        cuisineTypes = try container.decodeIfPresent([String].self, forKey: .cuisineTypes) ?? []
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        photos = try container.decodeIfPresent([String].self, forKey: .photos) ?? []
        distanceMiles = try container.decodeIfPresent(Double.self, forKey: .distanceMiles)
        isOpen = try container.decodeIfPresent(Bool.self, forKey: .isOpen)
    }
    
    // Custom initializer for creating from Restaurant objects
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
        isOpen: Bool? = nil
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
        self.isOpen = isOpen
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

// Extension to convert Restaurant back to RestaurantAPI for compatibility
extension Restaurant {
    func toRestaurantAPI() -> RestaurantAPI {
        return RestaurantAPI(
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
            isOpen: nil
        )
    }
}
