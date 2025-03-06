//
//  TilingMode.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation

/// Represents the available window tiling modes
enum TilingMode: String, CaseIterable {
    /// Binary Space Partitioning - recursive splitting of space
    case bsp
    
    /// Floating layout - windows are not automatically tiled
    case float
    
    /// Stack layout - windows are stacked on top of each other
    case stack

    /// Default tiling mode
    static var `default`: TilingMode { .bsp }
    
    /// Get the next mode in the cycle
    var next: TilingMode {
        switch self {
        case .bsp: return .stack
        case .stack: return .float
        case .float: return .bsp
        }
    }
    
    /// Human-readable description
    var description: String {
        switch self {
        case .bsp: return "Binary Space Partitioning"
        case .stack: return "Stack Layout"
        case .float: return "Floating Layout"
        }
    }
}
