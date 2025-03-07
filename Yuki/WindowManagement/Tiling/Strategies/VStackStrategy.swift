//
//  VStackStrategy.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

/// Strategy that arranges windows in a vertical stack
class VStackStrategy: TilingStrategy {
    var name: String { "vstack" }
    var description: String { "Vertical stack" }
    
    // Multithreaded implementation
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration, completion: @escaping ([WindowNode: NSRect]) -> Void) {
        guard !windows.isEmpty else {
            completion([:])
            return
        }
        
        let count = windows.count
        let totalGapHeight = config.windowGap * CGFloat(count - 1)
        let availableHeight = availableRect.height - (2 * config.outerGap) - totalGapHeight
        let windowHeight = availableHeight / CGFloat(count)
        
        // Use a concurrent queue for parallel calculation
        let calculationQueue = DispatchQueue(label: "com.yuki.vstackCalculation", attributes: .concurrent)
        let resultQueue = DispatchQueue(label: "com.yuki.vstackResults")
        
        // Store calculated frames without applying them yet
        var layouts: [WindowNode: NSRect] = [:]
        
        // Calculate all window frames in parallel
        let group = DispatchGroup()
        
        for (index, window) in windows.enumerated() {
            group.enter()
            calculationQueue.async {
                let y = availableRect.maxY - config.outerGap - windowHeight - CGFloat(index) * (windowHeight + config.windowGap)
                let frame = NSRect(
                    x: availableRect.minX + config.outerGap,
                    y: y,
                    width: availableRect.width - (2 * config.outerGap),
                    height: windowHeight
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
        let totalGapHeight = config.windowGap * CGFloat(count - 1)
        let availableHeight = availableRect.height - (2 * config.outerGap) - totalGapHeight
        let windowHeight = availableHeight / CGFloat(count)
        
        for (index, window) in windows.enumerated() {
            let y = availableRect.maxY - config.outerGap - windowHeight - CGFloat(index) * (windowHeight + config.windowGap)
            let frame = NSRect(
                x: availableRect.minX + config.outerGap,
                y: y,
                width: availableRect.width - (2 * config.outerGap),
                height: windowHeight
            )
            
            window.setFrame(frame)
        }
    }
}
