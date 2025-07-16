//
//  FavoritesView.swift
//  Tastewise
//
//  Created by AI Assistant
//

import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserFavorite.createdAt, order: .reverse) private var favorites: [UserFavorite]
    @Query private var restaurants: [Restaurant]
    
    var body: some View {
        VStack {
            if favorites.isEmpty {
                emptyStateView
            } else {
                favoritesList
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Favorites Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the heart icon on any restaurant to save it to your favorites.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var favoritesList: some View {
        List {
            ForEach(favorites, id: \.placeId) { favorite in
                if let restaurant = findRestaurant(for: favorite.placeId) {
                    NavigationLink(destination: RestaurantDetailView(restaurant: restaurant)) {
                        RestaurantCard(restaurant: restaurant, showFavoriteButton: false)
                    }
                } else {
                    // Fallback for restaurants not in current cache
                    VStack(alignment: .leading, spacing: 4) {
                        Text(favorite.restaurantName)
                            .font(.headline)
                        Text(favorite.restaurantAddress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Restaurant details not available")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteFavorites)
        }
        .listStyle(PlainListStyle())
    }
    
    private func findRestaurant(for placeId: String) -> Restaurant? {
        return restaurants.first { $0.placeId == placeId }
    }
    
    private func deleteFavorites(offsets: IndexSet) {
        for index in offsets {
            let favorite = favorites[index]
            modelContext.delete(favorite)
        }
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
    }
    .modelContainer(for: [UserFavorite.self, Restaurant.self, LocationCache.self], inMemory: true)
}
