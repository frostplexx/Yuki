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
