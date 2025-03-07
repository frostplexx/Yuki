//
//  TilingStrategy.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

/// Protocol defining a tiling strategy
protocol TilingStrategy {
    /// Apply layout to the given windows within the available space
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration)
    
    /// Apply layout with callback for multithreaded operation
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration, completion: @escaping ([WindowNode: NSRect]) -> Void)
    
    /// Name of the strategy
    var name: String { get }
    
    /// Description of the strategy
    var description: String { get }
}

/// Default implementation for backwards compatibility
extension TilingStrategy {
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration) {
        // Default implementation calls through to the completion handler version
        var layouts: [WindowNode: NSRect] = [:]
        
        // This is the entry point for the original implementation
        applyLayout(to: windows, in: availableRect, with: config) { result in
            layouts = result
        }
        
        // Apply the layouts synchronously if callback version not implemented
        for (window, rect) in layouts {
            window.setFrame(rect)
        }
    }
    
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration, completion: @escaping ([WindowNode: NSRect]) -> Void) {
        // Default implementation - subclasses should override this
        var layouts: [WindowNode: NSRect] = [:]
        
        // Calculate layouts but don't apply them directly
        for window in windows {
            // Default to full rect if strategy doesn't override
            layouts[window] = availableRect
        }
        
        // Return layouts through callback
        completion(layouts)
    }
}
