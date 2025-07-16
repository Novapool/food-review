//
//  MainTabView.swift
//  Tastewise
//
//  Created by AI Assistant
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Nearby Restaurants Tab
            NavigationStack {
                ContentView()
            }
            .tabItem {
                Label("Nearby", systemImage: "location.fill")
            }
            .tag(0)
            
            // Favorites Tab
            NavigationStack {
                FavoritesView()
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
            .tag(1)
            
            // Search Tab
            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(2)
            
            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(3)
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Restaurant.self, LocationCache.self, UserFavorite.self, UserPreferences.self], inMemory: true)
}
