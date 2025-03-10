//
//  WindowManager+Commands.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

// MARK: - Window Management Commands

extension WindowManager {
    // MARK: - Window Actions
    
    /// Focus the window at the specified position
    func focusWindowAt(position: NSPoint) {
        guard let monitor = monitorContaining(point: position),
              let workspace = monitor.activeWorkspace else { return }
        
        let windows = workspace.getAllWindowNodes()
        
        // Find the topmost window at this position
        for window in windows.reversed() {
            if let frame = window.frame, NSPointInRect(position, frame) {
                window.focus()
                break
            }
        }
    }
    
    /// Focus the next window in the current workspace
    func focusNextWindow() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        
        let windows = workspace.getAllWindowNodes()
        guard !windows.isEmpty else { return }
        
        // Find currently focused window
        let focusedWindowIndex = windows.firstIndex { window in
            window.window.get(Ax.isFocused) ?? false
        } ?? -1
        
        // Focus the next window
        let nextIndex = (focusedWindowIndex + 1) % windows.count
        windows[nextIndex].focus()
    }
    
    /// Focus the previous window in the current workspace
    func focusPreviousWindow() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        
        let windows = workspace.getAllWindowNodes()
        guard !windows.isEmpty else { return }
        
        // Find currently focused window
        let focusedWindowIndex = windows.firstIndex { window in
            window.window.get(Ax.isFocused) ?? false
        } ?? 0
        
        // Focus the previous window
        let prevIndex = (focusedWindowIndex - 1 + windows.count) % windows.count
        windows[prevIndex].focus()
    }
    
    /// Move the focused window to another workspace
    func moveFocusedWindowToWorkspace(_ workspace: WorkspaceNode) {
        guard let currentWorkspace = monitorWithMouse?.activeWorkspace else { return }
        
        // Skip if trying to move to the same workspace
        if workspace.id == currentWorkspace.id { return }
        
        // Find focused window
        guard let focusedWindow = getFocusedWindow(),
              let windowId = focusedWindow.systemWindowID,
              let intId = Int(windowId) else { return }
        
        // Use operations queue for improved performance
        windowOperationsQueue.async {
            // Move the window to the new workspace
            if let parent = focusedWindow.parent {
                var mutableParent = parent
                mutableParent.remove(focusedWindow)
            }
            
            // Add to new workspace
            workspace.children.append(focusedWindow)
            
            // Update ownership
            DispatchQueue.main.async {
                self.windowOwnership[intId] = workspace.id
            }
        }
    }
    
    /// Get the currently focused window
    private func getFocusedWindow() -> WindowNode? {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return nil }
        
        let windows = workspace.getAllWindowNodes()
        return windows.first { window in
            window.window.get(Ax.isFocused) ?? false
        }
    }
    
    /// Move the focused window to a specific monitor
    func moveFocusedWindowToMonitor(_ monitor: Monitor) {
        guard let focusedWindow = getFocusedWindow(),
              let workspace = monitor.activeWorkspace ?? monitor.workspaces.first else { return }
        
        moveFocusedWindowToWorkspace(workspace)
    }
    
    // MARK: - Window Arrangement
    
    /// Arrange all windows in the current workspace using HStack
    func arrangeCurrentWorkspaceHorizontally() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        workspace.setTilingMode("hstack")
    }
    
    /// Arrange all windows in the current workspace using VStack
    func arrangeCurrentWorkspaceVertically() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        workspace.setTilingMode("vstack")
    }
    
    /// Arrange all windows in the current workspace using ZStack
    func arrangeCurrentWorkspaceStacked() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        workspace.setTilingMode("zstack")
    }
    
    /// Set the current workspace to BSP mode
    func arrangeCurrentWorkspaceBSP() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        workspace.setTilingMode("bsp")
    }
    
    /// Set the current workspace to floating mode
    func floatCurrentWorkspace() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        workspace.setTilingMode("float")
    }
    
    // MARK: - Parallel Window Operations
    
    /// Batch process multiple window actions in parallel
    /// - Parameter operations: Array of closures that perform window operations
    func batchWindowOperations(_ operations: [() -> Void]) {
        let group = DispatchGroup()
        
        for operation in operations {
            group.enter()
            windowOperationsQueue.async {
                // Limit concurrent operations to avoid overwhelming the system
                self.operationsSemaphore.wait()
                
                operation()
                
                self.operationsSemaphore.signal()
                group.leave()
            }
        }
        
        // Optional: wait for completion if needed
        // group.wait()
    }
    
    /// Apply tiling operations in parallel from a TilingStrategy result
    /// - Parameter layoutMap: Dictionary mapping WindowNodes to target frames
    func applyLayoutOperationsInParallel(_ layoutMap: [WindowNode: NSRect]) {
        // Group windows by their process ID to minimize context switches
        let windowsByPID = Dictionary(grouping: layoutMap.keys) { WindowManager.shared.getPID(for: $0.window) }
        
        for (_, windows) in windowsByPID {
            let operations = windows.compactMap { window -> (() -> Void)? in
                guard let rect = layoutMap[window] else { return nil }
                return { window.setFrame(rect) }
            }
            
            batchWindowOperations(operations)
        }
    }
    
    /// Move multiple windows in parallel
    /// - Parameter windowMoves: Dictionary mapping WindowNodes to target positions
    func moveWindowsInParallel(_ windowMoves: [WindowNode: NSPoint]) {
        let operations = windowMoves.map { (window, position) in
            return {
                var cgPosition = CGPoint(x: position.x, y: position.y)
                if let positionValue = AXValueCreate(.cgPoint, &cgPosition) {
                    AXUIElementSetAttributeValue(
                        window.window,
                        kAXPositionAttribute as CFString,
                        positionValue
                    )
                }
            }
        }
        
        batchWindowOperations(operations)
    }
    
    /// Resize multiple windows in parallel
    /// - Parameter windowResizes: Dictionary mapping WindowNodes to target sizes
    func resizeWindowsInParallel(_ windowResizes: [WindowNode: NSSize]) {
        let operations = windowResizes.map { (window, size) in
            return {
                var cgSize = CGSize(width: size.width, height: size.height)
                if let sizeValue = AXValueCreate(.cgSize, &cgSize) {
                    AXUIElementSetAttributeValue(
                        window.window,
                        kAXSizeAttribute as CFString,
                        sizeValue
                    )
                }
            }
        }
        
        batchWindowOperations(operations)
    }
    
    /// Move and resize multiple windows in parallel
    /// - Parameter windowChanges: Dictionary mapping WindowNodes to (position, size) tuples
    func moveAndResizeWindowsInParallel(_ windowChanges: [WindowNode: (position: NSPoint, size: NSSize)]) {
        let operations = windowChanges.map { (window, changes) in
            return {
                // Resize first, then move for better visual results
                var cgSize = CGSize(width: changes.size.width, height: changes.size.height)
                var cgPosition = CGPoint(x: changes.position.x, y: changes.position.y)
                
                if let sizeValue = AXValueCreate(.cgSize, &cgSize),
                   let positionValue = AXValueCreate(.cgPoint, &cgPosition) {
                    
                    AXUIElementSetAttributeValue(
                        window.window,
                        kAXSizeAttribute as CFString,
                        sizeValue
                    )
                    
                    AXUIElementSetAttributeValue(
                        window.window,
                        kAXPositionAttribute as CFString,
                        positionValue
                    )
                }
            }
        }
        
        batchWindowOperations(operations)
    }
    
}
