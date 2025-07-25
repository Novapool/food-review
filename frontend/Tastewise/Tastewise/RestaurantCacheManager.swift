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
            
            // Save to cache directly without merging when doing a fresh API call
            try await saveToCache(
                restaurants: newRestaurants,
                location: location,
                radius: radius,
                context: context
            )
            
            // Update tracking
            lastSearchLocation = location
            lastSearchRadius = radius
            lastAPICall = Date()
            
            return RestaurantSearchResult(
                restaurants: newRestaurants,
                source: .api,
                cacheKey: LocationCache.createCacheKey(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radius: radius
                ),
                searchLocation: location,
                searchRadius: radius,
                totalFound: newRestaurants.count
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
        
        print("📦 Retrieved \(restaurants.count) restaurants from cache")
        return restaurants
    }
    
    
    private func saveToCache(
        restaurants: [Restaurant],
        location: CLLocation,
        radius: Double,
        context: ModelContext
    ) async throws {
        
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
        
        // Get existing restaurants from database to avoid duplicates
        let existingRestaurants = try getExistingRestaurants(restaurants: restaurants, context: context)
        
        // Merge and update restaurants
        let finalRestaurants = mergeRestaurants(new: restaurants, existing: existingRestaurants)
        
        // Save or update restaurants in database
        for restaurant in finalRestaurants {
            restaurant.lastSeen = Date()
            restaurant.searchCount += 1
            
            // Add cache location reference
            if restaurant.cacheLocations == nil {
                restaurant.cacheLocations = []
            }
            
            if !(restaurant.cacheLocations?.contains(cacheKey) ?? false) {
                restaurant.cacheLocations?.append(cacheKey)
            }
            
            context.insert(restaurant)
        }
        
        if let existingCache = existingCaches.first {
            // Update existing cache
            existingCache.restaurantPlaceIds = finalRestaurants.map { $0.placeId }
            existingCache.refreshExpiration()
            print("🔄 Updated existing cache: \(cacheKey) with \(finalRestaurants.count) restaurants")
        } else {
            // Create new cache
            let newCache = LocationCache(
                centerLatitude: location.coordinate.latitude,
                centerLongitude: location.coordinate.longitude,
                radiusMeters: radius,
                restaurantPlaceIds: finalRestaurants.map { $0.placeId }
            )
            
            context.insert(newCache)
            print("💾 Created new cache: \(cacheKey) with \(finalRestaurants.count) restaurants")
        }
        
        // Save all changes
        try context.save()
        
        // Cleanup old caches
        try await performCacheCleanup(context: context)
    }
    
    private func getExistingRestaurants(restaurants: [Restaurant], context: ModelContext) throws -> [Restaurant] {
        let placeIds = restaurants.map { $0.placeId }
        
        let predicate = #Predicate<Restaurant> { restaurant in
            placeIds.contains(restaurant.placeId)
        }
        
        let descriptor = FetchDescriptor<Restaurant>(predicate: predicate)
        return try context.fetch(descriptor)
    }
    
    private func mergeRestaurants(new: [Restaurant], existing: [Restaurant]) -> [Restaurant] {
        var restaurantMap: [String: Restaurant] = [:]
        
        // Add existing restaurants first
        for restaurant in existing {
            restaurantMap[restaurant.placeId] = restaurant
        }
        
        // Add or update with new restaurants
        for restaurant in new {
            if let existingRestaurant = restaurantMap[restaurant.placeId] {
                // Update existing restaurant with new data
                existingRestaurant.name = restaurant.name
                existingRestaurant.address = restaurant.address
                existingRestaurant.latitude = restaurant.latitude
                existingRestaurant.longitude = restaurant.longitude
                existingRestaurant.rating = restaurant.rating
                existingRestaurant.totalRatings = restaurant.totalRatings
                existingRestaurant.priceLevel = restaurant.priceLevel
                existingRestaurant.cuisineTypes = restaurant.cuisineTypes
                existingRestaurant.phone = restaurant.phone
                existingRestaurant.website = restaurant.website
                existingRestaurant.photos = restaurant.photos
                existingRestaurant.distanceMiles = restaurant.distanceMiles
                existingRestaurant.isRecommended = restaurant.isRecommended
                existingRestaurant.isPopular = restaurant.isPopular
                existingRestaurant.lastSeen = Date()
            } else {
                // Add new restaurant
                restaurantMap[restaurant.placeId] = restaurant
            }
        }
        
        let finalRestaurants = Array(restaurantMap.values)
        print("🔄 Merged \(new.count) new + \(existing.count) existing = \(finalRestaurants.count) unique restaurants")
        
        return finalRestaurants
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
        let sevenDaysAgo = -7 * 24 * 60 * 60.0 // 7 days in seconds
        let eightDaysAgo = -8 * 24 * 60 * 60.0 // 8 days in seconds (fallback for nil lastSeen)
        
        let orphanedRestaurants = allRestaurants.filter { restaurant in
            let isNotReferenced = !referencedPlaceIds.contains(restaurant.placeId)
            let lastSeenInterval = restaurant.lastSeen?.timeIntervalSinceNow ?? eightDaysAgo
            let isOld = lastSeenInterval < sevenDaysAgo
            
            return isNotReferenced && isOld
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
