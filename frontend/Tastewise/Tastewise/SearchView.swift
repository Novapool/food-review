//
//  SearchView.swift
//  Tastewise
//
//  Created by AI Assistant
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedCuisine: CuisineFilter = .all
    @State private var minRating: Double = 0.0
    @State private var maxDistance: Double = 10.0
    @State private var showingFilters = false
    
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            searchHeader
            
            // Filters section
            if showingFilters {
                filtersSection
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Results
            searchResults
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .animation(.easeInOut(duration: 0.3), value: showingFilters)
    }
    
    private var searchHeader: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search restaurants, cuisines...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Filter toggle and quick cuisines
            HStack {
                Button(action: { showingFilters.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Filters")
                        if hasActiveFilters {
                            Text("•")
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(showingFilters ? .blue : .primary)
                }
                
                Spacer()
                
                if hasActiveFilters {
                    Button("Clear", action: clearFilters)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            // Quick cuisine filters
            if !showingFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CuisineFilter.allCases.dropFirst(1), id: \.self) { cuisine in
                            QuickCuisineButton(
                                cuisine: cuisine,
                                isSelected: selectedCuisine == cuisine
                            ) {
                                selectedCuisine = selectedCuisine == cuisine ? .all : cuisine
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Cuisine filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Cuisine Type")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(CuisineFilter.allCases, id: \.self) { cuisine in
                        Button(action: { selectedCuisine = cuisine }) {
                            Text(cuisine == .all ? "All" : cuisine.displayName)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedCuisine == cuisine ? Color.blue : Color(.systemGray5))
                                .foregroundColor(selectedCuisine == cuisine ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
            }
            
            // Rating filter
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Minimum Rating")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(minRating == 0 ? "Any" : "\(minRating, specifier: "%.1f")+")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $minRating, in: 0...5, step: 0.5) {
                    Text("Rating")
                } minimumValueLabel: {
                    Text("0")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("5")
                        .font(.caption)
                }
            }
            
            // Distance filter
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Maximum Distance")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(maxDistance, specifier: "%.1f") miles")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $maxDistance, in: 1...25, step: 1) {
                    Text("Distance")
                } minimumValueLabel: {
                    Text("1")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("25")
                        .font(.caption)
                }
            }
            
            Divider()
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var searchResults: some View {
        VStack {
            if filteredRestaurants.isEmpty {
                emptyResultsView
            } else {
                List(filteredRestaurants, id: \.placeId) { restaurant in
                    NavigationLink(destination: RestaurantDetailView(restaurant: restaurant)) {
                        RestaurantCard(restaurant: restaurant)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var emptyResultsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "Enter a search term" : "No results found")
                .font(.title2)
                .fontWeight(.medium)
            
            if !searchText.isEmpty {
                Text("Try adjusting your search or filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var filteredRestaurants: [Restaurant] {
        restaurants.filter { restaurant in
            let matchesSearch = searchText.isEmpty ||
                restaurant.name.localizedCaseInsensitiveContains(searchText) ||
                restaurant.address.localizedCaseInsensitiveContains(searchText) ||
                restaurant.cuisineTypes.contains { $0.localizedCaseInsensitiveContains(searchText) }
            
            let matchesCuisine = selectedCuisine == .all ||
                restaurant.cuisineTypes.contains { $0.localizedCaseInsensitiveContains(selectedCuisine.rawValue) }
            
            let matchesRating = (restaurant.rating ?? 0) >= minRating
            
            let matchesDistance = (restaurant.distanceMiles ?? 0) <= maxDistance
            
            return matchesSearch && matchesCuisine && matchesRating && matchesDistance
        }
        .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }
    
    private var hasActiveFilters: Bool {
        selectedCuisine != .all || minRating > 0 || maxDistance < 10
    }
    
    private func clearFilters() {
        selectedCuisine = .all
        minRating = 0.0
        maxDistance = 10.0
    }
}

struct QuickCuisineButton: View {
    let cuisine: CuisineFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(cuisine.displayName)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
                .foregroundColor(isSelected ? .blue : .primary)
                .cornerRadius(16)
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
    .modelContainer(for: [Restaurant.self, LocationCache.self], inMemory: true)
}
