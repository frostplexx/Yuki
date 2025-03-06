//
//  WindowMoveObserver.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

/// Class that observes window movements and resizes
class WindowMoveObserver {
    /// Shared instance (singleton)
    static let shared = WindowMoveObserver()
    
    /// Timer for periodic checks
    private var observationTimer: Timer?
    
    /// Previously observed window positions
    private var previousWindowPositions: [Int: NSRect] = [:]
    
    /// Observation interval (in seconds)
    private let observationInterval: TimeInterval = 0.1
    
    private init() {
        // Start observation immediately
        startObserving()
    }
    
    deinit {
        stopObserving()
    }
    
    // MARK: - Observation Control
    
    /// Start observing window movements
    func startObserving() {
        stopObserving() // Stop any existing timer
        
        // Create initial window position cache
        updateWindowPositionCache()
        
        // Start timer to periodically check for window movements
        observationTimer = Timer.scheduledTimer(
            timeInterval: observationInterval,
            target: self,
            selector: #selector(checkForWindowMovements),
            userInfo: nil,
            repeats: true
        )
    }
    
    /// Stop observing window movements
    func stopObserving() {
        observationTimer?.invalidate()
        observationTimer = nil
    }
    
    // MARK: - Window Position Tracking
    
    /// Update the cache of window positions
    private func updateWindowPositionCache() {
        // Get current window list
        let windows = WindowManager.shared.windowDiscovery.getAllVisibleWindows()
        
        for windowInfo in windows {
            guard let windowId = windowInfo["kCGWindowNumber"] as? Int,
                  let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat else {
                continue
            }
            
            // Store current position and size
            let frame = NSRect(x: x, y: y, width: width, height: height)
            previousWindowPositions[windowId] = frame
        }
    }
    
    /// Check for window movements by comparing current positions to previous positions
    @objc private func checkForWindowMovements() {
        // Get current window list
        let windows = WindowManager.shared.windowDiscovery.getAllVisibleWindows()
        
        for windowInfo in windows {
            guard let windowId = windowInfo["kCGWindowNumber"] as? Int,
                  let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat,
                  let previousFrame = previousWindowPositions[windowId] else {
                continue
            }
            
            // Current frame
            let currentFrame = NSRect(x: x, y: y, width: width, height: height)
            
            // Check if position changed
            let positionThreshold: CGFloat = 2.0 // Small threshold to avoid false positives
            let positionChanged = abs(currentFrame.origin.x - previousFrame.origin.x) > positionThreshold ||
                                 abs(currentFrame.origin.y - previousFrame.origin.y) > positionThreshold
            
            // Check if size changed
            let sizeThreshold: CGFloat = 2.0
            let sizeChanged = abs(currentFrame.size.width - previousFrame.size.width) > sizeThreshold ||
                             abs(currentFrame.size.height - previousFrame.size.height) > sizeThreshold
            
            // Post appropriate notifications
            if positionChanged {
                WindowNotificationCenter.shared.postWindowMoved(windowId)
            }
            
            if sizeChanged {
                WindowNotificationCenter.shared.postWindowResized(windowId)
            }
            
            // Update stored position if changed
            if positionChanged || sizeChanged {
                previousWindowPositions[windowId] = currentFrame
            }
        }
        
        // Check for new windows
        let currentWindowIds = Set(windows.compactMap { $0["kCGWindowNumber"] as? Int })
        let previousWindowIds = Set(previousWindowPositions.keys)
        
        // New windows
        let newWindowIds = currentWindowIds.subtracting(previousWindowIds)
        for windowId in newWindowIds {
            WindowNotificationCenter.shared.postWindowCreated(windowId)
            
            // Add to tracking
            if let windowInfo = windows.first(where: { ($0["kCGWindowNumber"] as? Int) == windowId }),
               let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
               let x = bounds["X"] as? CGFloat,
               let y = bounds["Y"] as? CGFloat,
               let width = bounds["Width"] as? CGFloat,
               let height = bounds["Height"] as? CGFloat {
                
                previousWindowPositions[windowId] = NSRect(x: x, y: y, width: width, height: height)
            }
        }
        
        // Removed windows
        let removedWindowIds = previousWindowIds.subtracting(currentWindowIds)
        for windowId in removedWindowIds {
            WindowNotificationCenter.shared.postWindowRemoved(windowId)
            previousWindowPositions.removeValue(forKey: windowId)
        }
    }
}
