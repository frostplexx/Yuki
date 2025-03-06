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
        
        // Move the window to the new workspace
        if let parent = focusedWindow.parent {
            var mutableParent = parent
            mutableParent.remove(focusedWindow)
        }
        
        // Add to new workspace
        workspace.children.append(focusedWindow)
        
        // Update ownership
        windowOwnership[intId] = workspace.id
        
        // Apply tiling to affected workspaces
        if currentWorkspace.monitor.activeWorkspace == currentWorkspace {
//            currentWorkspace.applyTiling()
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
//        workspace.setTilingMode("hstack")
    }
    
    /// Arrange all windows in the current workspace using VStack
    func arrangeCurrentWorkspaceVertically() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
//        workspace.setTilingMode("vstack")
    }
    
    /// Arrange all windows in the current workspace using ZStack
    func arrangeCurrentWorkspaceStacked() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
//        workspace.setTilingMode("zstack")
    }
    
    /// Set the current workspace to BSP mode
    func arrangeCurrentWorkspaceBSP() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
//        workspace.setTilingMode("bsp")
    }
    
    /// Set the current workspace to floating mode
    func floatCurrentWorkspace() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
//        workspace.setTilingMode("float")
    }
    
    /// Toggle through available tiling modes for the current workspace
    func cycleCurrentWorkspaceTilingMode() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        
//        let nextMode = workspace.cycleToNextTilingMode()
//        print("Switched workspace \(workspace.title ?? "Unknown") to \(nextMode.name) mode")
    }
}
