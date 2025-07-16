//
//  UserPreferences.swift
//  Tastewise
//
//  Created by AI Assistant
//

import Foundation
import SwiftData

@Model
final class UserPreferences {
    @Attribute(.unique) var id: String = "default"
    var defaultRadius: Double = 16093.0 // 10 miles in meters
    var minRating: Double = 0.0
    var preferredCuisines: [String] = []
    var autoReloadDistance: Double = 1609.0 // 1 mile in meters
    var lastUpdated: Date
    
    init() {
        self.lastUpdated = Date()
    }
    
    // Helper computed properties
    var defaultRadiusMiles: Double {
        return defaultRadius * 0.000621371
    }
    
    var autoReloadDistanceMiles: Double {
        return autoReloadDistance * 0.000621371
    }
    
    // Methods to update preferences
    func updateRadius(miles: Double) {
        defaultRadius = miles * 1609.34
        lastUpdated = Date()
    }
    
    func updateAutoReloadDistance(miles: Double) {
        autoReloadDistance = miles * 1609.34
        lastUpdated = Date()
    }
}
