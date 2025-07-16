//
//  SettingsView.swift
//  Tastewise
//
//  Created by AI Assistant
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]
    
    @State private var defaultRadius: Double = 10.0
    @State private var minRating: Double = 0.0
    @State private var autoReloadDistance: Double = 1.0
    @State private var showingClearCacheAlert = false
    
    var body: some View {
        List {
            Section("Search Preferences") {
                // Default radius setting
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Default Search Radius")
                            .font(.subheadline)
                        Spacer()
                        Text("\(defaultRadius, specifier: "%.1f") miles")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $defaultRadius, in: 1...25, step: 1)
                        .onChange(of: defaultRadius) { _, _ in
                            savePreferences()
                        }
                }
                .padding(.vertical, 4)
                
                // Minimum rating setting
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Default Minimum Rating")
                            .font(.subheadline)
                        Spacer()
                        Text(minRating == 0 ? "Any" : "\(minRating, specifier: "%.1f")+")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $minRating, in: 0...5, step: 0.5)
                        .onChange(of: minRating) { _, _ in
                            savePreferences()
                        }
                }
                .padding(.vertical, 4)
                
                // Auto-reload distance setting
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Auto-reload Distance")
                            .font(.subheadline)
                        Spacer()
                        Text("\(autoReloadDistance, specifier: "%.1f") miles")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $autoReloadDistance, in: 0.1...5, step: 0.1)
                        .onChange(of: autoReloadDistance) { _, _ in
                            savePreferences()
                        }
                }
                .padding(.vertical, 4)
                
                Text("App will automatically search for new restaurants when you move more than this distance.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Data Management") {
                Button("Clear All Cache") {
                    showingClearCacheAlert = true
                }
                .foregroundColor(.red)
                
                Text("This will clear all cached restaurant data and force fresh searches.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("App Information") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("2025.01.1")
                        .foregroundColor(.secondary)
                }
                
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    .foregroundColor(.blue)
                
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                    .foregroundColor(.blue)
            }
            
            Section("About") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tastewise")
                        .font(.headline)
                    
                    Text("Discover amazing restaurants near you with AI-powered recommendations and smart caching.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadPreferences()
        }
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will delete all cached restaurant data. The app will need to reload restaurants from the internet.")
        }
    }
    
    private func loadPreferences() {
        if let prefs = preferences.first {
            defaultRadius = prefs.defaultRadiusMiles
            minRating = prefs.minRating
            autoReloadDistance = prefs.autoReloadDistanceMiles
        } else {
            // Create default preferences if none exist
            let defaultPrefs = UserPreferences()
            modelContext.insert(defaultPrefs)
            try? modelContext.save()
        }
    }
    
    private func savePreferences() {
        let prefs = preferences.first ?? UserPreferences()
        prefs.updateRadius(miles: defaultRadius)
        prefs.minRating = minRating
        prefs.updateAutoReloadDistance(miles: autoReloadDistance)
        
        if preferences.isEmpty {
            modelContext.insert(prefs)
        }
        
        try? modelContext.save()
    }
    
    private func clearCache() {
        do {
            try RestaurantCacheManager.shared.clearAllCache(context: modelContext)
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [UserPreferences.self], inMemory: true)
}
