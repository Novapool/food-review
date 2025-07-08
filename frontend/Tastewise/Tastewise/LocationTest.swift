//
//  LocationTest.swift
//  Tastewise
//
//  Created by Laith Assaf on 1/5/25.
//

import Foundation

// Simple test function to verify location sending works
class LocationTest {
    static func testLocationSending() async {
        print("🧪 Testing location sending to Supabase...")
        
        // Create test location data
        let testLocation = LocationData(
            latitude: 37.7749,  // San Francisco coordinates
            longitude: -122.4194,
            accuracy: 10.0,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        
        do {
            let success = try await SupabaseService.shared.sendLocation(testLocation)
            if success {
                print("✅ Location test successful!")
                print("📍 Sent: \(testLocation.latitude), \(testLocation.longitude)")
            } else {
                print("❌ Location test failed - server returned false")
            }
        } catch {
            print("❌ Location test failed with error: \(error)")
        }
    }
}
