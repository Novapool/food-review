//
//  TastewiseApp.swift
//  Tastewise
//
//  Created by Laith Assaf on 6/24/25.
//

import SwiftUI
import SwiftData

@main
struct TastewiseApp: App {
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Restaurant.self,
            LocationCache.self,
        ])
        
        // Configure with migration options
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, try to handle it gracefully
            print("⚠️ ModelContainer creation failed: \(error)")
            
            // Check if it's a migration error
            if let nsError = error as NSError?,
               nsError.domain == "NSCocoaErrorDomain" && nsError.code == 134110 {
                print("🔄 Detected migration error - attempting recovery...")
                
                // Try to backup and reset the store
                return handleMigrationFailure(schema: schema, configuration: modelConfiguration)
            } else {
                print("❌ Unknown error creating ModelContainer: \(error)")
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()
    
    private static func handleMigrationFailure(schema: Schema, configuration: ModelConfiguration) -> ModelContainer {
        let storeURL = configuration.url
        let backupURL = storeURL.appendingPathExtension("backup")
        
        do {
            // Try to backup the existing store
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try? FileManager.default.removeItem(at: backupURL) // Remove old backup
                try FileManager.default.moveItem(at: storeURL, to: backupURL)
                print("📦 Backed up existing store to: \(backupURL)")
            }
            
            // Create new container with fresh store
            let newContainer = try ModelContainer(for: schema, configurations: [configuration])
            print("✅ Successfully created new ModelContainer after migration failure")
            
            // Show user notification about data reset (in a real app, you might want to show an alert)
            print("ℹ️ Database was reset due to migration issues. Previous data was backed up.")
            
            return newContainer
            
        } catch {
            print("❌ Failed to create ModelContainer even after backup: \(error)")
            fatalError("Could not create ModelContainer even after migration recovery: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
