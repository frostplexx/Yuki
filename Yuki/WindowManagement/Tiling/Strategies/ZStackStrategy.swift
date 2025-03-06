//
//  ZStackStrategy.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

/// Strategy that stacks windows on top of each other
class ZStackStrategy: TilingStrategy {
    var name: String { "zstack" }
    var description: String { "Windows stacked on top of each other" }
    
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration) {
        guard !windows.isEmpty else { return }
        
        let frame = NSRect(
            x: availableRect.minX + config.outerGap,
            y: availableRect.minY + config.outerGap,
            width: availableRect.width - (2 * config.outerGap),
            height: availableRect.height - (2 * config.outerGap)
        )
        
        // Set all windows to cover the entire area
        for window in windows {
            window.setFrame(frame)
        }
        
        // Bring the last window to the front
        if let lastWindow = windows.last {
            lastWindow.focus()
        }
    }
}
