//
//  HStackStrategy.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

/// Strategy that arranges windows in a horizontal stack
class HStackStrategy: TilingStrategy {
    var name: String { "hstack" }
    var description: String { "Horizontal stack" }
    
    // Add multithreaded implementation
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration, completion: @escaping ([WindowNode: NSRect]) -> Void) {
        guard !windows.isEmpty else {
            completion([:])
            return
        }
        
        let count = windows.count
        let totalGapWidth = config.windowGap * CGFloat(count - 1)
        let availableWidth = availableRect.width - (2 * config.outerGap) - totalGapWidth
        let windowWidth = availableWidth / CGFloat(count)
        
//        print("HStack: Calculating layout for \(count) windows with width \(windowWidth)")
        
        // Use a concurrent queue for parallel calculation
        let calculationQueue = DispatchQueue(label: "com.yuki.hstackCalculation", attributes: .concurrent)
        let resultQueue = DispatchQueue(label: "com.yuki.hstackResults")
        
        // Store calculated frames without applying them yet
        var layouts: [WindowNode: NSRect] = [:]
        
        // Calculate all window frames in parallel
        let group = DispatchGroup()
        
        for (index, window) in windows.enumerated() {
            group.enter()
            calculationQueue.async {
                let x = availableRect.minX + config.outerGap + CGFloat(index) * (windowWidth + config.windowGap)
                let frame = NSRect(
                    x: x,
                    y: availableRect.minY + config.outerGap,
                    width: windowWidth,
                    height: availableRect.height - (2 * config.outerGap)
                )
                
                resultQueue.async {
                    layouts[window] = frame
                    group.leave()
                }
            }
        }
        
        // Wait for all calculations to complete
        group.notify(queue: .main) {
            // Return the calculated layouts through the completion handler
            completion(layouts)
        }
    }
    
    // Original implementation for backward compatibility
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration) {
        guard !windows.isEmpty else { return }
        
        let count = windows.count
        let totalGapWidth = config.windowGap * CGFloat(count - 1)
        let availableWidth = availableRect.width - (2 * config.outerGap) - totalGapWidth
        let windowWidth = availableWidth / CGFloat(count)
        
        for (index, window) in windows.enumerated() {
            let x = availableRect.minX + config.outerGap + CGFloat(index) * (windowWidth + config.windowGap)
            let frame = NSRect(
                x: x,
                y: availableRect.minY + config.outerGap,
                width: windowWidth,
                height: availableRect.height - (2 * config.outerGap)
            )
            
            window.setFrame(frame)
        }
    }
}
