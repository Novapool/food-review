//
//  LocationCache.swift
//  Tastewise
//
//  Created by Laith Assaf on 1/16/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class LocationCache {
    @Attribute(.unique) var cacheKey: String
    var centerLatitude: Double
    var centerLongitude: Double
    var radiusMeters: Double
    var searchTimestamp: Date
    var expiresAt: Date
    private var restaurantPlaceIdsData: Data?
    
    // Computed property for array access
    var restaurantPlaceIds: [String] {
        get {
            guard let data = restaurantPlaceIdsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            restaurantPlaceIdsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    init(
        centerLatitude: Double,
        centerLongitude: Double,
        radiusMeters: Double,
        restaurantPlaceIds: [String] = []
    ) {
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.radiusMeters = radiusMeters
        self.searchTimestamp = Date()
        self.expiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days
        
        // Create cache key from location and radius
        self.cacheKey = LocationCache.createCacheKey(
            latitude: centerLatitude,
            longitude: centerLongitude,
            radius: radiusMeters
        )
        
        // Set restaurant place IDs after all stored properties are initialized
        self.restaurantPlaceIds = restaurantPlaceIds
    }
    
    // MARK: - Cache Key Generation
    
    static func createCacheKey(latitude: Double, longitude: Double, radius: Double) -> String {
        // Round to 4 decimal places for consistency (~11 meters precision)
        let roundedLat = round(latitude * 10000) / 10000
        let roundedLng = round(longitude * 10000) / 10000
        let roundedRadius = round(radius)
        
        return "\(roundedLat)_\(roundedLng)_\(roundedRadius)"
    }
    
    // MARK: - Cache Validation
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var isValid: Bool {
        return !isExpired && !restaurantPlaceIds.isEmpty
    }
    
    // MARK: - Location Utilities
    
    var centerLocation: CLLocation {
        return CLLocation(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    func distanceTo(_ location: CLLocation) -> CLLocationDistance {
        return centerLocation.distance(from: location)
    }
    
    func contains(_ location: CLLocation) -> Bool {
        return distanceTo(location) <= radiusMeters
    }
    
    // MARK: - Cache Overlap Detection
    
    func overlaps(with otherCache: LocationCache) -> Bool {
        let distance = distanceTo(otherCache.centerLocation)
        let combinedRadius = radiusMeters + otherCache.radiusMeters
        return distance < combinedRadius
    }
    
    func overlapPercentage(with otherCache: LocationCache) -> Double {
        let distance = distanceTo(otherCache.centerLocation)
        let combinedRadius = radiusMeters + otherCache.radiusMeters
        
        if distance >= combinedRadius {
            return 0.0 // No overlap
        }
        
        // Calculate overlap area using circle intersection formula
        let r1 = radiusMeters
        let r2 = otherCache.radiusMeters
        let d = distance
        
        if d <= abs(r1 - r2) {
            // One circle is completely inside the other
            let smallerRadius = min(r1, r2)
            return (smallerRadius * smallerRadius) / (r1 * r1) * 100
        }
        
        // Partial overlap calculation
        let area1 = r1 * r1 * acos((d * d + r1 * r1 - r2 * r2) / (2 * d * r1))
        let area2 = r2 * r2 * acos((d * d + r2 * r2 - r1 * r1) / (2 * d * r2))
        let area3 = 0.5 * sqrt((-d + r1 + r2) * (d + r1 - r2) * (d - r1 + r2) * (d + r1 + r2))
        
        let overlapArea = area1 + area2 - area3
        let thisArea = .pi * r1 * r1
        
        return (overlapArea / thisArea) * 100
    }
    
    // MARK: - Cache Statistics
    
    var ageInHours: Double {
        return Date().timeIntervalSince(searchTimestamp) / 3600
    }
    
    var remainingLifeInHours: Double {
        return max(0, expiresAt.timeIntervalSince(Date()) / 3600)
    }
    
    // MARK: - Cache Metadata
    
    func addRestaurants(_ placeIds: [String]) {
        let uniqueIds = Set(restaurantPlaceIds + placeIds)
        restaurantPlaceIds = Array(uniqueIds)
    }
    
    func removeRestaurant(_ placeId: String) {
        restaurantPlaceIds.removeAll { $0 == placeId }
    }
    
    func refreshExpiration() {
        expiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60) // Reset to 7 days
        searchTimestamp = Date()
    }
    
    // MARK: - Debug Information
    
    var debugDescription: String {
        return """
        LocationCache:
        - Key: \(cacheKey)
        - Center: \(centerLatitude), \(centerLongitude)
        - Radius: \(radiusMeters)m
        - Restaurants: \(restaurantPlaceIds.count)
        - Age: \(String(format: "%.1f", ageInHours))h
        - Expires: \(String(format: "%.1f", remainingLifeInHours))h
        - Valid: \(isValid)
        """
    }
}

// MARK: - LocationCache Extensions

extension LocationCache {
    
    // MARK: - Cache Query Helpers
    
    static func findRelevantCaches(
        for location: CLLocation,
        radius: Double,
        in context: ModelContext
    ) throws -> [LocationCache] {
        
        let currentDate = Date()
        let predicate = #Predicate<LocationCache> { cache in
            cache.expiresAt > currentDate
        }
        
        let descriptor = FetchDescriptor<LocationCache>(predicate: predicate)
        let allCaches = try context.fetch(descriptor)
        
        // Filter caches that overlap with our search area
        return allCaches.filter { cache in
            let distance = cache.distanceTo(location)
            let combinedRadius = cache.radiusMeters + radius
            return distance < combinedRadius
        }
    }
    
    static func findBestCache(
        for location: CLLocation,
        radius: Double,
        in context: ModelContext
    ) throws -> LocationCache? {
        
        let relevantCaches = try findRelevantCaches(for: location, radius: radius, in: context)
        
        // Score caches based on coverage and freshness
        let scoredCaches = relevantCaches.compactMap { cache -> (cache: LocationCache, score: Double)? in
            guard cache.isValid else { return nil }
            
            let distance = cache.distanceTo(location)
            let coverage = max(0, min(1, (cache.radiusMeters - distance) / radius))
            let freshness = max(0, min(1, cache.remainingLifeInHours / 168)) // 168 hours = 7 days
            
            let score = coverage * 0.7 + freshness * 0.3
            return (cache: cache, score: score)
        }
        
        return scoredCaches.max(by: { $0.score < $1.score })?.cache
    }
    
    // MARK: - Cache Cleanup
    
    static func cleanupExpiredCaches(in context: ModelContext) throws {
        let currentDate = Date()
        let predicate = #Predicate<LocationCache> { cache in
            cache.expiresAt < currentDate
        }
        
        let descriptor = FetchDescriptor<LocationCache>(predicate: predicate)
        let expiredCaches = try context.fetch(descriptor)
        
        for cache in expiredCaches {
            context.delete(cache)
        }
        
        if !expiredCaches.isEmpty {
            try context.save()
            print("🗑️ Cleaned up \(expiredCaches.count) expired location caches")
        }
    }
    
    static func manageCacheSize(maxCaches: Int = 50, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<LocationCache>(
            sortBy: [SortDescriptor(\.searchTimestamp, order: .reverse)]
        )
        
        let allCaches = try context.fetch(descriptor)
        
        if allCaches.count > maxCaches {
            let cachesToDelete = Array(allCaches.dropFirst(maxCaches))
            
            for cache in cachesToDelete {
                context.delete(cache)
            }
            
            try context.save()
            print("📦 Removed \(cachesToDelete.count) old location caches to manage size")
        }
    }
}

// MARK: - Cache Statistics Extension

extension LocationCache {
    
    struct CacheStats {
        let totalCaches: Int
        let validCaches: Int
        let expiredCaches: Int
        let totalRestaurants: Int
        let averageAge: Double
        let oldestCache: Date?
        let newestCache: Date?
        let averageRadius: Double
        let storageSize: Int // Approximate size in bytes
    }
    
    static func getCacheStatistics(in context: ModelContext) throws -> CacheStats {
        let descriptor = FetchDescriptor<LocationCache>()
        let allCaches = try context.fetch(descriptor)
        
        let validCaches = allCaches.filter { $0.isValid }
        let expiredCaches = allCaches.filter { $0.isExpired }
        
        let totalRestaurants = allCaches.reduce(0) { $0 + $1.restaurantPlaceIds.count }
        let averageAge = allCaches.isEmpty ? 0 : allCaches.reduce(0) { $0 + $1.ageInHours } / Double(allCaches.count)
        let averageRadius = allCaches.isEmpty ? 0 : allCaches.reduce(0) { $0 + $1.radiusMeters } / Double(allCaches.count)
        
        let oldestCache = allCaches.min(by: { $0.searchTimestamp < $1.searchTimestamp })?.searchTimestamp
        let newestCache = allCaches.max(by: { $0.searchTimestamp < $1.searchTimestamp })?.searchTimestamp
        
        // Rough storage size calculation
        let storageSize = allCaches.reduce(0) { total, cache in
            total + cache.cacheKey.count + cache.restaurantPlaceIds.reduce(0) { $0 + $1.count } + 200 // ~200 bytes overhead per cache
        }
        
        return CacheStats(
            totalCaches: allCaches.count,
            validCaches: validCaches.count,
            expiredCaches: expiredCaches.count,
            totalRestaurants: totalRestaurants,
            averageAge: averageAge,
            oldestCache: oldestCache,
            newestCache: newestCache,
            averageRadius: averageRadius,
            storageSize: storageSize
        )
    }
}
