//
//  StringArrayTransformer.swift
//  Tastewise
//
//  Created by Laith Assaf on 1/16/25.
//

import Foundation
import SwiftData

@objc(StringArrayTransformer)
final class StringArrayTransformer: NSSecureUnarchiveFromDataTransformer {
    
    static let name = NSValueTransformerName(rawValue: String(describing: StringArrayTransformer.self))
    
    override static var allowedTopLevelClasses: [AnyClass] {
        return [NSArray.self, NSString.self]
    }
    
    public static func register() {
        let transformer = StringArrayTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let stringArray = value as? [String] else { return nil }
        
        do {
            let data = try JSONEncoder().encode(stringArray)
            return data
        } catch {
            print("Error encoding string array: \(error)")
            return nil
        }
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return [] }
        
        do {
            let stringArray = try JSONDecoder().decode([String].self, from: data)
            return stringArray
        } catch {
            print("Error decoding string array: \(error)")
            return []
        }
    }
}
