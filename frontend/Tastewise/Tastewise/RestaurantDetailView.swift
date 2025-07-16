//
//  RestaurantDetailView.swift
//  Tastewise
//
//  Created by AI Assistant
//

import SwiftUI
import MapKit

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isFavorite = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with photos
                headerSection
                
                // Restaurant info
                infoSection
                
                // Map
                mapSection
                
                // Contact info
                contactSection
                
                Spacer(minLength: 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(restaurant.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .gray)
                        .font(.system(size: 20))
                }
                .animation(.spring(response: 0.3), value: isFavorite)
            }
        }
        .onAppear {
            checkFavoriteStatus()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Photo placeholder - will be enhanced later with actual photos
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text(restaurant.primaryCuisine)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                )
                .cornerRadius(12)
            
            // Restaurant basic info
            VStack(alignment: .leading, spacing: 8) {
                Text(restaurant.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                if let rating = restaurant.rating {
                    HStack(spacing: 8) {
                        Text(restaurant.ratingStars)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(restaurant.formattedRating)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            if let totalRatings = restaurant.totalRatings {
                                Text("(\(totalRatings) reviews)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if !restaurant.priceDisplay.isEmpty {
                            Text(restaurant.priceDisplay)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Cuisine types
                if !restaurant.cuisineTypes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(restaurant.cuisineTypes, id: \.self) { cuisine in
                                Text(cuisine)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, -20)
                }
            }
        }
        .padding()
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Address
            VStack(alignment: .leading, spacing: 8) {
                Label("Address", systemImage: "location")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(restaurant.address)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !restaurant.formattedDistance.isEmpty {
                    Text(restaurant.formattedDistance + " from your location")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            // Badges
            if restaurant.badgeText != nil {
                HStack {
                    if let badgeText = restaurant.badgeText {
                        Text(badgeText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                restaurant.badgeColor == "purple" ?
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Location", systemImage: "map")
                .font(.headline)
                .padding(.horizontal)
            
            Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: restaurant.latitude,
                    longitude: restaurant.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )), annotationItems: [restaurant]) { restaurant in
                MapMarker(coordinate: CLLocationCoordinate2D(
                    latitude: restaurant.latitude,
                    longitude: restaurant.longitude
                ), tint: .red)
            }
            .frame(height: 200)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if restaurant.phone != nil || restaurant.website != nil {
                Label("Contact", systemImage: "phone")
                    .font(.headline)
                
                if let phone = restaurant.phone {
                    Button(action: { callRestaurant(phone) }) {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.green)
                            Text(phone)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if let website = restaurant.website {
                    Button(action: { openWebsite(website) }) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                            Text("Visit Website")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func checkFavoriteStatus() {
        isFavorite = FavoritesManager.shared.isFavorite(restaurant, context: modelContext)
    }
    
    private func toggleFavorite() {
        FavoritesManager.shared.toggleFavorite(restaurant, context: modelContext)
        isFavorite = FavoritesManager.shared.isFavorite(restaurant, context: modelContext)
    }
    
    private func callRestaurant(_ phone: String) {
        let cleanedPhone = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel://\(cleanedPhone)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openWebsite(_ website: String) {
        var urlString = website
        if !website.hasPrefix("http://") && !website.hasPrefix("https://") {
            urlString = "https://\(website)"
        }
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        RestaurantDetailView(restaurant: Restaurant(
            placeId: "preview_id",
            name: "Sample Restaurant",
            address: "123 Main St, Sample City, SC 12345",
            latitude: 37.7749,
            longitude: -122.4194,
            rating: 4.5,
            totalRatings: 123,
            priceLevel: 2,
            cuisineTypes: ["Italian", "Pizza"],
            distanceMiles: 0.8,
            isRecommended: true,
            isPopular: false
        ))
    }
    .modelContainer(for: [Restaurant.self, UserFavorite.self], inMemory: true)
}
