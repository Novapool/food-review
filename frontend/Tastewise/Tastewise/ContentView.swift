//
//  ContentView.swift
//  Tastewise
//
//  Created by Laith Assaf on 6/24/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    @State private var locationManager = LocationManager()
    
    @State private var selectedSortOption: RestaurantSortOption = .nearby
    @State private var selectedCuisineFilter: CuisineFilter = .all
    @State private var searchText = ""
    @State private var showingLocationAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Restaurant List
                restaurantListView
            }
            .navigationBarHidden(true)
            .alert("Location Permission Required", isPresented: $showingLocationAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable location services in Settings to find nearby restaurants.")
            }
            .onChange(of: locationManager.authorizationStatus) { _, status in
                if status == .denied || status == .restricted {
                    showingLocationAlert = true
                }
            }
            .onAppear {
                setupLocationManager()
                locationManager.requestLocation()
                
                // Run test in development
                #if DEBUG
                Task {
                    await LocationTest.testLocationSending()
                }
                #endif
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupLocationManager() {
        locationManager.setModelContext(modelContext)
        locationManager.onRestaurantsLoaded = { searchResponse in
            Task { @MainActor in
                await loadRestaurantsFromAPI(searchResponse)
            }
        }
    }
    
    private func loadRestaurantsFromAPI(_ searchResponse: RestaurantSearchResponse) async {
        // Note: RestaurantCacheManager already handles saving restaurants to the database
        // This method now just serves as a callback confirmation that restaurants were loaded
        
        let source = searchResponse.message?.contains("cache") == true ? "cache" : "API"
        print("✅ Loaded \(searchResponse.restaurants.count) restaurants from \(source)")
        
        // The restaurants are already in the database via RestaurantCacheManager
        // The @Query in ContentView will automatically update the UI
        
        // Optional: Force a UI refresh if needed
        // The SwiftData @Query should automatically update, but we can trigger a save to ensure consistency
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save context: \(error)")
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Location Info
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                
                Text(locationText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if locationManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search restaurants or cuisine", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Filter Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RestaurantSortOption.allCases, id: \.self) { option in
                        FilterTab(
                            title: option.displayName,
                            isSelected: selectedSortOption == option
                        ) {
                            selectedSortOption = option
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Quick Actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CuisineFilter.allCases.dropFirst(), id: \.self) { cuisine in
                        QuickActionButton(
                            title: cuisine.displayName,
                            isSelected: selectedCuisineFilter == cuisine
                        ) {
                            selectedCuisineFilter = cuisine
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Restaurant List View
    
    private var restaurantListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if locationManager.location == nil && !locationManager.isLoading {
                    // Location Capture View
                    locationCaptureView
                } else if locationManager.isLoadingRestaurants {
                    // Loading restaurants
                    loadingRestaurantsView
                } else if restaurants.isEmpty {
                    // Empty State
                    emptyStateView
                } else {
                    // Restaurant Cards
                    ForEach(filteredAndSortedRestaurants, id: \.placeId) { restaurant in
                        RestaurantCard(restaurant: restaurant)
                            .onTapGesture {
                                // TODO: Navigate to restaurant details
                                print("Tapped restaurant: \(restaurant.name)")
                            }
                    }
                    
                    // Refresh Button
                    refreshButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Space for bottom navigation
        }
        .refreshable {
            await refreshRestaurants()
        }
    }
    
    // MARK: - Location Capture View
    
    private var locationCaptureView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "location.magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Find Restaurants Near You")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("We need your location to show nearby restaurants and provide personalized recommendations.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                locationManager.requestLocation()
            }) {
                HStack {
                    if locationManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "location.magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                    }
                    
                    Text(locationManager.isLoading ? "Getting Location..." : "Get My Location")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(locationManager.isLoading)
            .padding(.horizontal)
            
            if let error = locationManager.locationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Restaurants Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your filters or search in a different area.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let error = locationManager.restaurantError {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
            
            Button("Try Again") {
                Task {
                    await refreshRestaurants()
                }
            }
            .padding(.top, 16)
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 100)
    }
    
    // MARK: - Loading Restaurants View
    
    private var loadingRestaurantsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)
                
                Text("Finding Restaurants Near You")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Searching for the best dining options in your area...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Refresh Button
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await refreshRestaurants()
            }
        }) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Refresh Restaurants")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.blue)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Restaurant Search Functions
    
    private func refreshRestaurants() async {
        guard let location = locationManager.location else {
            locationManager.requestLocation()
            return
        }
        
        await locationManager.searchNearbyRestaurants()
    }
    
    // MARK: - Computed Properties
    
    private var locationText: String {
        if let location = locationManager.location {
            if locationManager.isLoadingRestaurants {
                return "Searching restaurants • 10 miles"
            } else {
                return "Current location • 10 miles"
            }
        } else if locationManager.isLoading {
            return "Getting your location..."
        } else {
            return "Location not available"
        }
    }
    
    private var filteredAndSortedRestaurants: [Restaurant] {
        var filtered = restaurants
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { restaurant in
                restaurant.name.localizedCaseInsensitiveContains(searchText) ||
                restaurant.cuisineTypes.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply cuisine filter
        if selectedCuisineFilter != .all {
            filtered = filtered.filter { restaurant in
                restaurant.cuisineTypes.contains { cuisine in
                    cuisine.localizedCaseInsensitiveContains(selectedCuisineFilter.rawValue)
                }
            }
        }
        
        // Apply sorting
        switch selectedSortOption {
        case .nearby:
            filtered.sort { ($0.distanceMiles ?? 999) < ($1.distanceMiles ?? 999) }
        case .recommended:
            filtered.sort { $0.isRecommended && !$1.isRecommended }
        case .topRated:
            filtered.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .priceLow:
            filtered.sort { ($0.priceLevel ?? 0) < ($1.priceLevel ?? 0) }
        case .priceHigh:
            filtered.sort { ($0.priceLevel ?? 0) > ($1.priceLevel ?? 0) }
        case .mostReviewed:
            filtered.sort { ($0.totalRatings ?? 0) > ($1.totalRatings ?? 0) }
        }
        
        return filtered
    }
}

// MARK: - Supporting Views

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
                .foregroundColor(isSelected ? .blue : .secondary)
                .cornerRadius(16)
        }
    }
}

struct RestaurantCard: View {
    let restaurant: Restaurant
    
    var body: some View {
        HStack(spacing: 12) {
            // Restaurant Info
            VStack(alignment: .leading, spacing: 8) {
                Text(restaurant.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(restaurant.primaryCuisine)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    // Rating
                    if let rating = restaurant.rating {
                        HStack(spacing: 4) {
                            Text(restaurant.ratingStars)
                                .font(.caption)
                            Text(restaurant.formattedRating)
                                .font(.caption)
                                .fontWeight(.medium)
                            if let totalRatings = restaurant.totalRatings {
                                Text("(\(totalRatings))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Distance
                    if !restaurant.formattedDistance.isEmpty {
                        Text(restaurant.formattedDistance)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    
                    // Price
                    if !restaurant.priceDisplay.isEmpty {
                        Text(restaurant.priceDisplay)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Badge
                if let badgeText = restaurant.badgeText {
                    Text(badgeText)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            restaurant.badgeColor == "purple" ? 
                            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Restaurant Image Placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                )
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Restaurant.self, LocationCache.self], inMemory: true)
}
