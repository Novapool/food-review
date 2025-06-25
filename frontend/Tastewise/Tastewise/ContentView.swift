//
//  ContentView.swift
//  Tastewise
//
//  Created by Laith Assaf on 6/24/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // App Logo/Title
                VStack {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Restaurant Finder")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Welcome Message
                VStack(spacing: 10) {
                    Text("Welcome!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Find amazing restaurants near you")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Placeholder Button for Future Features
                Button(action: {
                    print("Find Restaurants tapped!")
                }) {
                    HStack {
                        Image(systemName: "location.magnifyingglass")
                        Text("Find Restaurants")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    ContentView()
}
