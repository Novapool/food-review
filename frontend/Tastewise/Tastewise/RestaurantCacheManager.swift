//
//  RestaurantCacheManager.swift
//  Tastewise
//
//  Created by Laith Assaf on 1/16/25.
//

import Foundation
import SwiftData
import CoreLocation

@Observable
class RestaurantCacheManager {
    
    // MARK: - Properties
    
    static let shared = RestaurantCacheManager()
    
    private let reloadDistanceThreshold: Double = 1609.0 // 1 mile in meters
    private let defaultRadius: Double = 16093.0 // 10 miles in meters
    private let cacheExpirationHours: Double = 168.0 // 7 days in hours
    
    // Track last search location to determine if reload is needed
    private var lastSearchLocation: CLLocation?
    private var lastSearchRadius: Double = 16093.0
    
    // Loading states
    var isLoadingFromCache = false
    var isLoadingFromAPI = false
    var lastCacheHit: Date?
    var lastAPICall: Date?
    
    private init() {}
    
    // MARK: - Main Search Method
    
    func searchRestaurants(
        location: CLLocation,
        radius: Double = 16093.0,
        context: ModelContext,
        forceReload: Bool = false
    ) async throws -> RestaurantSearchResult {
        
        print("🔍 Starting restaurant search for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Check if we need to reload based on distance
        let needsReload = forceReload || shouldReloadForLocation(location, radius: radius)
        
        if needsReload {
            print("🔄 Reload needed - distance threshold exceeded or forced")
            return try await performFullSearch(location: location, radius: radius, context: context)
        } else {
            print("⚡ Using cached results - within distance threshold")
            return try await getCachedResults(location: location, radius: radius, context: context)
        }
    }
    
    // MARK: - Distance-Based Reload Logic
    
    private func shouldReloadForLocation(_ location: CLLocation, radius: Double) -> Bool {
        // No previous search - definitely need to reload
        guard let lastLocation = lastSearchLocation else {
            print("📍 No previous search location - reload required")
            return true
        }
        
        // Check distance from last search
        let distance = location.distance(from: lastLocation)
        let needsReload = distance >= reloadDistanceThreshold
        
        print("📏 Distance from last search: \(Int(distance))m (threshold: \(Int(reloadDistanceThreshold))m)")
        
        // Also reload if radius changed significantly
        let radiusChanged = abs(radius - lastSearchRadius) > 1000 // 1km difference
        
        if radiusChanged {
            print("🎯 Radius changed significantly - reload required")
        }
        
        return needsReload || radiusChanged
    }
    
    // MARK: - Cache-First Search
    
    private func getCachedResults(
        location: CLLocation,
        radius: Double,
        context: ModelContext
    ) async throws -> RestaurantSearchResult {
        
        isLoadingFromCache = true
        defer { isLoadingFromCache = false }
        
        do {
            // Find best matching cache
            let bestCache = try LocationCache.findBestCache(for: location, radius: radius, in: context)
            
            if let cache = bestCache, cache.isValid {
                print("✅ Found valid cache: \(cache.cacheKey)")
                
                // Get restaurants from cache
                let restaurants = try getRestaurantsFromCache(cache: cache, context: context)
                
                // Filter by distance if needed
                let filteredRestaurants = filterRestaurantsByDistance(
                    restaurants,
                    from: location,
                    radius: radius
                )
                
                lastCacheHit = Date()
                
                return RestaurantSearchResult(
                    restaurants: filteredRestaurants,
                    source: .cache,
                    cacheKey: cache.cacheKey,
                    searchLocation: location,
                    searchRadius: radius,
                    totalFound: filteredRestaurants.count
                )
            } else {
                print("❌ No valid cache found - falling back to API")
                return try await performFullSearch(location: location, radius: radius, context: context)
            }
            
        } catch {
            print("❌ Cache lookup failed: \(error) - falling back to API")
            return try await performFullSearch(location: location, radius: radius, context: context)
        }
    }
    
    // MARK: - Full API Search with Caching
    
    private func performFullSearch(
        location: CLLocation,
        radius: Double,
        context: ModelContext
    ) async throws -> RestaurantSearchResult {
        
        isLoadingFromAPI = true
        defer { isLoadingFromAPI = false }
        
        do {
            // Get fresh results from API
            let apiResponse = try await SupabaseService.shared.searchRestaurants(
                location: location,
                radius: radius
            )
            
            print("🌐 API returned \(apiResponse.restaurants.count) restaurants")
            
            // Convert API results to local Restaurant models
            let newRestaurants = apiResponse.restaurants.map { apiRestaurant in
                apiRestaurant.toRestaurant(
                    isRecommended: apiRestaurant.rating ?? 0 > 4.5,
                    isPopular: apiRestaurant.totalRatings ?? 0 > 100
                )
            }
            
            // Merge with existing cache if available
            let mergedRestaurants = try await mergeWithExistingCache(
                newRestaurants: newRestaurants,
                location: location,
                radius: radius,
                context: context
            )
            
            // Save to cache
            try await saveToCache(
                restaurants: mergedRestaurants,
                location: location,
                radius: radius,
                context: context
            )
            
            // Update tracking
            lastSearchLocation = location
            lastSearchRadius = radius
            lastAPICall = Date()
            
            return RestaurantSearchResult(
                restaurants: mergedRestaurants,
                source: .api,
                cacheKey: LocationCache.createCacheKey(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radius: radius
                ),
                searchLocation: location,
                searchRadius: radius,
                totalFound: mergedRestaurants.count
            )
            
        } catch {
            print("❌ API search failed: \(error)")
            
            // Try to return stale cache as fallback
            if let fallbackResult = try? await getStaleCache(location: location, radius: radius, context: context) {
                print("🔄 Returning stale cache as fallback")
                return fallbackResult
            }
            
            throw error
        }
    }
    
    // MARK: - Cache Operations
    
    private func getRestaurantsFromCache(
        cache: LocationCache,
        context: ModelContext
    ) throws -> [Restaurant] {
        
        // Fetch restaurants by place IDs
        let placeIds = cache.restaurantPlaceIds
        
        let predicate = #Predicate<Restaurant> { restaurant in
            placeIds.contains(restaurant.placeId)
        }
        
        let descriptor = FetchDescriptor<Restaurant>(predicate: predicate)
        let restaurants = try context.fetch(descriptor)
        
        // Update lastSeen for cache hit tracking
        for restaurant in restaurants {
            restaurant.lastSeen = Date()
            restaurant.searchCount += 1
        }
        
        return restaurants
    }
    
    private func mergeWithExistingCache(
        newRestaurants: [Restaurant],
        location: CLLocation,
        radius: Double,
        context: ModelContext
    ) async throws -> [Restaurant] {
        
        // Find overlapping caches
        let overlappingCaches = try LocationCache.findRelevantCaches(
            for: location,
            radius: radius,
            in: context
        )
        
        // Get existing restaurants from overlapping caches
        var existingRestaurants: [Restaurant] = []
        
        for cache in overlappingCaches {
            let cacheRestaurants = try getRestaurantsFromCache(cache: cache, context: context)
            existingRestaurants.append(contentsOf: cacheRestaurants)
        }
        
        // Merge new and existing restaurants, avoiding duplicates
        var mergedRestaurants = newRestaurants
        let newPlaceIds = Set(newRestaurants.map { $0.placeId })
        
        // Add existing restaurants that aren't in new results
        for existingRestaurant in existingRestaurants {
            if !newPlaceIds.contains(existingRestaurant.placeId) {
                // Check if still within search radius
                let restaurantLocation = CLLocation(
                    latitude: existingRestaurant.latitude,
                    longitude: existingRestaurant.longitude
                )
                
                if location.distance(from: restaurantLocation) <= radius {
                    mergedRestaurants.append(existingRestaurant)
                }
            }
        }
        
        // Remove duplicates by place_id (keep newer data)
        var uniqueRestaurants: [String: Restaurant] = [:]
        
        for restaurant in mergedRestaurants {
            if let existing = uniqueRestaurants[restaurant.placeId] {
                // Keep the more recently updated one
                if restaurant.createdAt > existing.createdAt {
                    uniqueRestaurants[restaurant.placeId] = restaurant
                }
            } else {
                uniqueRestaurants[restaurant.placeId] = restaurant
            }
        }
        
        let finalRestaurants = Array(uniqueRestaurants.values)
        
        print("🔄 Merged \(newRestaurants.count) new + \(existingRestaurants.count) existing = \(finalRestaurants.count) unique restaurants")
        
        return finalRestaurants
    }
    
    private func saveToCache(
        restaurants: [Restaurant],
        location: CLLocation,
        radius: Double,
        context: ModelContext
    ) async throws {
        
        // Save or update restaurants in database
        for restaurant in restaurants {
            restaurant.lastSeen = Date()
            restaurant.searchCount += 1
            
            // Add cache location reference
            let cacheKey = LocationCache.createCacheKey(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: radius
            )
            
            if !restaurant.cacheLocations.contains(cacheKey) {
                restaurant.cacheLocations.append(cacheKey)
            }
            
            context.insert(restaurant)
        }
        
        // Create or update location cache
        let cacheKey = LocationCache.createCacheKey(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radius: radius
        )
        
        // Check if cache already exists
        let predicate = #Predicate<LocationCache> { cache in
            cache.cacheKey == cacheKey
        }
        
        let descriptor = FetchDescriptor<LocationCache>(predicate: predicate)
        let existingCaches = try context.fetch(descriptor)
        
        if let existingCache = existingCaches.first {
            // Update existing cache
            existingCache.restaurantPlaceIds = restaurants.map { $0.placeId }
            existingCache.refreshExpiration()
            print("🔄 Updated existing cache: \(cacheKey)")
        } else {
            // Create new cache
            let newCache = LocationCache(
                centerLatitude: location.coordinate.latitude,
                centerLongitude: location.coordinate.longitude,
                radiusMeters: radius,
                restaurantPlaceIds: restaurants.map { $0.placeId }
            )
            
            context.insert(newCache)
            print("💾 Created new cache: \(cacheKey)")
        }
        
        // Save all changes
        try context.save()
        
        // Cleanup old caches
        try await performCacheCleanup(context: context)
    }
    
    private func getStaleCache(
        location: CLLocation,
        radius: Double,
        context: ModelContext
    ) async throws -> RestaurantSearchResult? {
        
        // Look for expired but recent caches as fallback
        let relevantCaches = try LocationCache.findRelevantCaches(
            for: location,
            radius: radius,
            in: context
        )
        
        // Find the most recent cache (even if expired)
        let mostRecentCache = relevantCaches.max(by: { $0.searchTimestamp < $1.searchTimestamp })
        
        if let cache = mostRecentCache {
            let restaurants = try getRestaurantsFromCache(cache: cache, context: context)
            
            return RestaurantSearchResult(
                restaurants: restaurants,
                source: .staleCache,
                cacheKey: cache.cacheKey,
                searchLocation: location,
                searchRadius: radius,
                totalFound: restaurants.count
            )
        }
        
        return nil
    }
    
    // MARK: - Cache Maintenance
    
    private func performCacheCleanup(context: ModelContext) async throws {
        // Clean up expired caches
        try LocationCache.cleanupExpiredCaches(in: context)
        
        // Manage cache size
        try LocationCache.manageCacheSize(maxCaches: 50, in: context)
        
        // Clean up orphaned restaurants (not referenced by any cache)
        try await cleanupOrphanedRestaurants(context: context)
    }
    
    private func cleanupOrphanedRestaurants(context: ModelContext) async throws {
        let allRestaurants = try context.fetch(FetchDescriptor<Restaurant>())
        let allCaches = try context.fetch(FetchDescriptor<LocationCache>())
        
        // Get all place IDs that are referenced by caches
        let referencedPlaceIds = Set(allCaches.flatMap { $0.restaurantPlaceIds })
        
        // Find orphaned restaurants
        let orphanedRestaurants = allRestaurants.filter { restaurant in
            !referencedPlaceIds.contains(restaurant.placeId) &&
            restaurant.lastSeen.timeIntervalSinceNow < -7 * 24 * 60 * 60 // Older than 7 days
        }
        
        if !orphanedRestaurants.isEmpty {
            for restaurant in orphanedRestaurants {
                context.delete(restaurant)
            }
            
            try context.save()
            print("🗑️ Cleaned up \(orphanedRestaurants.count) orphaned restaurants")
        }
    }
    
    // MARK: - Utility Methods
    
    private func filterRestaurantsByDistance(
        _ restaurants: [Restaurant],
        from location: CLLocation,
        radius: Double
    ) -> [Restaurant] {
        
        return restaurants.filter { restaurant in
            let restaurantLocation = CLLocation(
                latitude: restaurant.latitude,
                longitude: restaurant.longitude
            )
            
            let distance = location.distance(from: restaurantLocation)
            
            // Update distance in restaurant object
            restaurant.distanceMiles = distance * 0.000621371 // Convert meters to miles
            
            return distance <= radius
        }
    }
    
    // MARK: - Public Cache Information
    
    func getCacheInfo(for location: CLLocation, radius: Double, context: ModelContext) throws -> CacheInfo? {
        let bestCache = try LocationCache.findBestCache(for: location, radius: radius, in: context)
        
        guard let cache = bestCache else { return nil }
        
        return CacheInfo(
            cacheKey: cache.cacheKey,
            isValid: cache.isValid,
            restaurantCount: cache.restaurantPlaceIds.count,
            ageInHours: cache.ageInHours,
            remainingLifeInHours: cache.remainingLifeInHours,
            distance: cache.distanceTo(location),
            coverage: min(1.0, cache.radiusMeters / radius)
        )
    }
    
    func getCacheStatistics(context: ModelContext) throws -> LocationCache.CacheStats {
        return try LocationCache.getCacheStatistics(in: context)
    }
    
    // MARK: - Force Reload
    
    func forceReload(location: CLLocation, radius: Double, context: ModelContext) async throws -> RestaurantSearchResult {
        print("🔄 Force reloading restaurants for location")
        lastSearchLocation = nil // Reset to force reload
        return try await searchRestaurants(location: location, radius: radius, context: context, forceReload: true)
    }
    
    // MARK: - Clear Cache
    
    func clearAllCache(context: ModelContext) throws {
        let allCaches = try context.fetch(FetchDescriptor<LocationCache>())
        let allRestaurants = try context.fetch(FetchDescriptor<Restaurant>())
        
        for cache in allCaches {
            context.delete(cache)
        }
        
        for restaurant in allRestaurants {
            context.delete(restaurant)
        }
        
        try context.save()
        lastSearchLocation = nil
        
        print("🗑️ Cleared all cache data")
    }
}

// MARK: - Supporting Types

enum SearchSource {
    case cache
    case api
    case staleCache
}

struct RestaurantSearchResult {
    let restaurants: [Restaurant]
    let source: SearchSource
    let cacheKey: String
    let searchLocation: CLLocation
    let searchRadius: Double
    let totalFound: Int
    
    var isFromCache: Bool {
        return source == .cache
    }
    
    var isFromAPI: Bool {
        return source == .api
    }
    
    var isStale: Bool {
        return source == .staleCache
    }
}

struct CacheInfo {
    let cacheKey: String
    let isValid: Bool
    let restaurantCount: Int
    let ageInHours: Double
    let remainingLifeInHours: Double
    let distance: Double // Distance from cache center to search location
    let coverage: Double // How much of the search radius is covered (0.0 to 1.0)
    
    var coveragePercentage: Int {
        return Int(coverage * 100)
    }
    
    var isExpired: Bool {
        return remainingLifeInHours <= 0
    }
}
