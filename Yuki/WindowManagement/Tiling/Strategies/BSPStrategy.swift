//
//  BSPStrategy.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

/// Strategy that implements Binary Space Partitioning
class BSPStrategy: TilingStrategy {
    var name: String { "bsp" }
    var description: String { "Binary Space Partitioning" }
    
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration) {
        guard !windows.isEmpty else {
            print("Warning: Empty windows array in BSP")
            return
        }
        
//        print("BSP: Starting layout for \(windows.count) windows")
        
        // Apply outer gap
        let rect = NSRect(
            x: availableRect.minX + config.outerGap,
            y: availableRect.minY + config.outerGap,
            width: availableRect.width - (2 * config.outerGap),
            height: availableRect.height - (2 * config.outerGap)
        )
        
        // Simple BSP implementation that directly sets window frames
        applyBSPDirect(windows: windows, rect: rect, orientation: .h, config: config)
    }
    
    // Version with callback for multithreaded operation (required by protocol)
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration, completion: @escaping ([WindowNode: NSRect]) -> Void) {
        // This is just to satisfy the protocol, the direct version is what's used
        var layouts: [WindowNode: NSRect] = [:]
        completion(layouts)
    }
    
    // Super simple and direct BSP implementation
    private func applyBSPDirect(windows: [WindowNode], rect: NSRect, orientation: Orientation, config: TilingConfiguration) {
        // If only one window, it gets the whole space
        if windows.count == 1, let window = windows.first {
//            print("BSP: Single window gets entire space: \(rect)")
            window.setFrame(rect)
            return
        }
        
        // Split the array in half
        let mid = windows.count / 2
        let firstHalf = Array(windows.prefix(mid))
        let secondHalf = Array(windows.suffix(from: mid))
        
//        print("BSP: Splitting \(windows.count) windows - First: \(firstHalf.count), Second: \(secondHalf.count)")
        
        // Split the rectangle based on orientation
        let (firstRect, secondRect) = splitRect(rect, orientation: orientation, gap: config.windowGap)
        
        // Recursively apply BSP with alternating orientation
        let nextOrientation = orientation.opposite
        applyBSPDirect(windows: firstHalf, rect: firstRect, orientation: nextOrientation, config: config)
        applyBSPDirect(windows: secondHalf, rect: secondRect, orientation: nextOrientation, config: config)
    }
    
    private func splitRect(_ rect: NSRect, orientation: Orientation, gap: CGFloat) -> (NSRect, NSRect) {
        switch orientation {
        case .h:
            let width = (rect.width - gap) / 2
            let firstRect = NSRect(x: rect.minX, y: rect.minY, width: width, height: rect.height)
            let secondRect = NSRect(x: rect.minX + width + gap, y: rect.minY, width: width, height: rect.height)
            return (firstRect, secondRect)
            
        case .v:
            let height = (rect.height - gap) / 2
            let firstRect = NSRect(x: rect.minX, y: rect.minY + height + gap, width: rect.width, height: height)
            let secondRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: height)
            return (firstRect, secondRect)
        }
    }
}
