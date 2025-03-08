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
    
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration, completion: @escaping ([WindowNode: NSRect]) -> Void) {
        guard !windows.isEmpty else {
            completion([:])
            return
        }
        
        let frame = NSRect(
            x: availableRect.minX + config.outerGap,
            y: availableRect.minY + config.outerGap,
            width: availableRect.width - (2 * config.outerGap),
            height: availableRect.height - (2 * config.outerGap)
        )
        
        var layouts: [WindowNode: NSRect] = [:]
        
        let calculationQueue = DispatchQueue(label: "com.yuki.zstackCalculation", attributes: .concurrent)
        let resultQueue = DispatchQueue(label: "com.yuki.zstackResults")
        let group = DispatchGroup()
        
        for window in windows {
            group.enter()
            calculationQueue.async {
                resultQueue.async {
                    layouts[window] = frame
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(layouts)
        }
    }
    
    func applyLayout(to windows: [WindowNode], in availableRect: NSRect, with config: TilingConfiguration) {
        guard !windows.isEmpty else { return }
        
        let frame = NSRect(
            x: availableRect.minX + config.outerGap,
            y: availableRect.minY + config.outerGap,
            width: availableRect.width - (2 * config.outerGap),
            height: availableRect.height - (2 * config.outerGap)
        )
        
        for window in windows {
            window.setFrame(frame)
        }
        
        if let lastWindow = windows.last {
            lastWindow.focus()
        }
    }
}
