//
//  LocationManager.swift
//  Tastewise
//
//  Created by Laith Assaf on 1/5/25.
//

import CoreLocation
import Foundation
import Observation
import SwiftData

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    
    var location: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var locationError: String?
    var isLoading = false
    var isLoadingRestaurants = false
    var restaurantError: String?
    
    // Restaurant search callback
    var onRestaurantsLoaded: ((RestaurantSearchResult) -> Void)?
    
    // ModelContext for cache operations
    private var modelContext: ModelContext?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0 // Only update if moved 10 meters
    }
    
    // MARK: - ModelContext Setup
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func requestLocation() {
        isLoading = true
        locationError = nil
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable location services in Settings."
            isLoading = false
        @unknown default:
            locationError = "Unknown location authorization status"
            isLoading = false
        }
    }
    
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocation()
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            locationError = "Location access denied"
            isLoading = false
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Only update if the location is significantly different or more accurate
        if let currentLocation = location {
            let distance = newLocation.distance(from: currentLocation)
            if distance < 10.0 && newLocation.horizontalAccuracy >= currentLocation.horizontalAccuracy {
                return
            }
        }
        
        location = newLocation
        isLoading = false
        
        print("📍 Location updated: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
        
        // Send location to Supabase and search for restaurants
        Task {
            await sendLocationToSupabase(location: newLocation)
            await searchNearbyRestaurants()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error.localizedDescription
        isLoading = false
        print("Location error: \(error.localizedDescription)")
    }
    
    // MARK: - Restaurant Search
    
    func searchNearbyRestaurants() async {
        guard let currentLocation = location else {
            restaurantError = "Location not available"
            return
        }
        
        guard let context = modelContext else {
            restaurantError = "Database context not available"
            return
        }
        
        isLoadingRestaurants = true
        restaurantError = nil
        
        do {
            // Use RestaurantCacheManager instead of direct API call
            let searchResult = try await RestaurantCacheManager.shared.searchRestaurants(
                location: currentLocation,
                context: context
            )
            
            await MainActor.run {
                self.isLoadingRestaurants = false
                self.onRestaurantsLoaded?(searchResult)
            }
            
        } catch {
            await MainActor.run {
                self.isLoadingRestaurants = false
                self.restaurantError = error.localizedDescription
                print("❌ Failed to search restaurants: \(error)")
            }
        }
    }
    
    // MARK: - Send to Supabase
    
    private func sendLocationToSupabase(location: CLLocation) async {
        let locationData = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: ISO8601DateFormatter().string(from: location.timestamp)
        )
        
        do {
            let success = try await SupabaseService.shared.sendLocation(locationData)
            if success {
                print("Location sent to Supabase successfully")
            } else {
                print("Failed to send location to Supabase")
            }
        } catch {
            print("Error sending location to Supabase: \(error)")
        }
    }
}

// MARK: - Location Data Model

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: String
}

// MARK: - Location Response Model

struct LocationResponse: Codable {
    let success: Bool
    let message: String
    let location: ReceivedLocation?
    let error: String?
}

struct ReceivedLocation: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let received_at: String
}
