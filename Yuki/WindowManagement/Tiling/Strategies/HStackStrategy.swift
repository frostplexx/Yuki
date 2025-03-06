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
    
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration) {
        guard !windows.isEmpty else { return }
        
        let count = windows.count
        let totalGapWidth = config.windowGap * CGFloat(count - 1)
        let availableWidth = availableRect.width - (2 * config.outerGap) - totalGapWidth
        let windowWidth = availableWidth / CGFloat(count)
        
        print("HStack: Laying out \(count) windows with width \(windowWidth)")
        
        for (index, window) in windows.enumerated() {
            let x = availableRect.minX + config.outerGap + CGFloat(index) * (windowWidth + config.windowGap)
            let frame = NSRect(
                x: x,
                y: availableRect.minY + config.outerGap,
                width: windowWidth,
                height: availableRect.height - (2 * config.outerGap)
            )
            
            print("Setting window \(index) frame to \(frame)")
            window.setFrame(frame)
        }
    }
}
