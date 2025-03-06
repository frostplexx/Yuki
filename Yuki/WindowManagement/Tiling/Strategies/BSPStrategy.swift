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
        guard !windows.isEmpty else { return }
        
        // Apply outer gap
        let rect = NSRect(
            x: availableRect.minX + config.outerGap,
            y: availableRect.minY + config.outerGap,
            width: availableRect.width - (2 * config.outerGap),
            height: availableRect.height - (2 * config.outerGap)
        )
        
        applyBSP(windows: windows, rect: rect, orientation: .h, config: config)
    }
    
    private func applyBSP(windows: [WindowNode], rect: NSRect, orientation: Orientation, config: TilingConfiguration) {
        // If only one window, it gets the whole space
        if windows.count == 1, let window = windows.first {
            window.setFrame(rect)
            return
        }
        
        // Split the array in half
        let mid = windows.count / 2
        let firstHalf = Array(windows.prefix(mid))
        let secondHalf = Array(windows.suffix(from: mid))
        
        // Split the rectangle based on orientation
        let (firstRect, secondRect) = splitRect(rect, orientation: orientation, gap: config.windowGap)
        
        // Recursively apply BSP with alternating orientation
        let nextOrientation = orientation.opposite
        applyBSP(windows: firstHalf, rect: firstRect, orientation: nextOrientation, config: config)
        applyBSP(windows: secondHalf, rect: secondRect, orientation: nextOrientation, config: config)
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
