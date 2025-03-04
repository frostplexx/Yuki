//
//  WindowPositionData.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa

/// Structure to store a window's position and size together
struct WindowPositionData {
    /// The position of the window (usually top-left corner)
    let position: NSPoint
    
    /// The size of the window
    let size: NSSize
    
    /// Initializes window position data with position and size
    /// - Parameters:
    ///   - position: The position of the window
    ///   - size: The size of the window
    init(position: NSPoint, size: NSSize) {
        self.position = position
        self.size = size
    }
    
    /// Constructs a rect from the position and size
    var rect: NSRect {
        return NSRect(origin: position, size: size)
    }
    
    /// Returns a description of the window data
    var description: String {
        return "Position: (\(position.x), \(position.y)), Size: \(size.width)x\(size.height)"
    }
}
