//
//  WindowManager+Updates.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa

// MARK: - WindowManager Window Tracking Extensions

extension WindowManager {
    /// Set up window tracking
    func setupWindowTracking() {
        // Set up window observation
        setupWindowObservation()
    }
    
    /// Periodic check for window changes
    @objc func periodicWindowCheck() {
        checkForWindowChanges()
    }
    
    /// Get the latest window stacking order from the system
    /// - Returns: Array of window IDs in stacking order (front to back)
    func getWindowStackingOrder() -> [Int] {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
            return []
        }
        
        return windowList.compactMap { $0["kCGWindowNumber"] as? Int }
    }
    
    /// Update window stacking order in the active workspace
    func updateWindowStacking() {
        guard let workspace = selectedWorkspace,
              let _ = workspace.monitor else {
            return
        }
        
        // Get the current stacking order from the system
        let systemStackingOrder = getWindowStackingOrder()
        
        // Filter to only include windows in this workspace
        let workspaceWindowIds = Set(workspace.root.getAllWindowNodes().compactMap { $0.systemWindowID })
        let relevantStackingOrder = systemStackingOrder.filter { workspaceWindowIds.contains($0) }
        
        // If we have at least two windows to stack, update the order
        if relevantStackingOrder.count >= 2 {
            applyWindowStackingOrder(workspace: workspace, stackingOrder: relevantStackingOrder)
        }
    }
    
    /// Apply window stacking order to a workspace
    /// - Parameters:
    ///   - workspace: The workspace to update
    ///   - stackingOrder: The window IDs in stacking order (front to back)
    private func applyWindowStackingOrder(workspace: Workspace, stackingOrder: [Int]) {
        // Get a map of window ID to window node
        var windowNodesById: [Int: WindowNode] = [:]
        for windowNode in workspace.root.getAllWindowNodes() {
            if let windowId = windowNode.systemWindowID {
                windowNodesById[windowId] = windowNode
            }
        }
        
        // Apply the stacking order (front to back, so reverse the array)
        for windowId in stackingOrder.reversed() {
            if let windowNode = windowNodesById[windowId] {
                // Raise the window - the last one raised will be on top
                windowNode.focus()
                
                // Small delay to ensure proper stacking
                usleep(10000) // 10ms
            }
        }
    }
    
    /// Initialize window tracking when app starts
    func initializeWindowTracking() {
        // Set up window tracking
        setupWindowTracking()
        
        // Initial window refresh
        refreshWindows()
    }
}


// MARK: - WindowManager Instance Provider

/// Utility class to provide a singleton instance of the window manager
class WindowManagerProvider {
    /// Shared window manager instance
    static let shared: WindowManager = {
        let manager = WindowManager()
        return manager
    }()
}
