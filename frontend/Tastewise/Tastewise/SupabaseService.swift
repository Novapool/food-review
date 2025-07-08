//
//  SupabaseService.swift
//  Tastewise
//
//  Created by Laith Assaf on 1/5/25.
//

import Foundation

class SupabaseService {
    static let shared = SupabaseService()
    
    // Supabase configuration
    private let supabaseURL = "https://wwvabzmpqhchtftesxsx.supabase.co"
    private let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind3dmFiem1wcWhjaHRmdGVzeHN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA4Nzg3ODYsImV4cCI6MjA2NjQ1NDc4Nn0.HZG6vuZpFZjMCMnzanSjCVNcCdjrq95H6yniSmlWQpE"
    
    private init() {}
    
    func sendLocation(_ locationData: LocationData) async throws -> Bool {
        guard let url = URL(string: "\(supabaseURL)/functions/v1/handle-location") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        do {
            let jsonData = try JSONEncoder().encode(locationData)
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }
            
            print("HTTP Status Code: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                let locationResponse = try JSONDecoder().decode(LocationResponse.self, from: data)
                return locationResponse.success
            } else {
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(LocationResponse.self, from: data) {
                    throw SupabaseError.serverError(errorResponse.error ?? "Unknown error")
                } else {
                    throw SupabaseError.httpError(httpResponse.statusCode)
                }
            }
            
        } catch let error as DecodingError {
            print("Decoding error: \(error)")
            throw SupabaseError.decodingError
        } catch let error as SupabaseError {
            throw error
        } catch {
            print("Network error: \(error)")
            throw SupabaseError.networkError(error)
        }
    }
}

// MARK: - Error Handling

enum SupabaseError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case httpError(Int)
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .serverError(let message):
            return "Server error: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
