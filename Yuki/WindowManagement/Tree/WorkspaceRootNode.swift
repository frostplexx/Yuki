//
//  WorkspaceRootNode.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Cocoa
import Foundation

/// Root node for a workspace
class WorkspaceNode: Node {

    var type: NodeType { .rootNode }
    var children: [any Node] = []
    var parent: (any Node)? = nil
    let id: UUID = UUID()
    var title: String?

    var monitor: Monitor

    // Store window elements directly along with their states
    private struct SavedWindowState {
        let window: AXUIElement
        let position: NSPoint
        let size: NSSize
        let title: String?
    }
    
    // Array to store window states
    private var savedWindowStates: [SavedWindowState] = []

    init(title: String? = "Root", monitor: Monitor) {
        self.title = title
        self.monitor = monitor
    }

    /// Finds a window node by system window ID
    /// - Parameter systemWindowID: The system window ID to find
    /// - Returns: The window node if found, nil otherwise
    func findWindowNode(systemWindowID: String) -> WindowNode? {
        // Check direct children
        for child in children {
            if let windowNode = child as? WindowNode,
                windowNode.systemWindowID == systemWindowID
            {
                return windowNode
            }
        }

        // Check container children
        for child in children {
            if let container = child as? ContainerNode {
                for subChild in container.children {
                    if let windowNode = subChild as? WindowNode,
                        windowNode.systemWindowID == systemWindowID
                    {
                        return windowNode
                    }
                }
            }
        }

        return nil
    }

    /// Gets all window nodes in the workspace
    /// - Returns: Array of all window nodes
    func getAllWindowNodes() -> [WindowNode] {
        var result: [WindowNode] = []

        // Check direct children
        for child in children {
            if let windowNode = child as? WindowNode {
                result.append(windowNode)
            }
        }

        // Check container children
        for child in children {
            if let container = child as? ContainerNode {
                for subChild in container.children {
                    if let windowNode = subChild as? WindowNode {
                        result.append(windowNode)
                    }
                }
            }
        }

        return result
    }

    /// Override adoptWindow to include ownership tracking and avoid duplicates
    func adoptWindow(_ window: AXUIElement) {
        // Get the window ID
        var windowId: CGWindowID = 0
        guard _AXUIElementGetWindow(window, &windowId) == .success else {
            print("Failed to get window ID during adoption")
            return
        }

        // Check if window is already owned by a workspace
        if let intId = Int(exactly: windowId),
            WindowManager.shared.windowOwnership[intId] == nil
        {
            // Create a window node
            let windowNode = WindowNode(window)

            // Add to ownership if not already tracked
            WindowManager.shared.windowOwnership[intId] = self.id

            // Add as a child
            self.children.append(windowNode)

            // Only move if the workspace is not active
            if monitor.activeWorkspace?.id != self.id {
                windowNode.move(
                    to: .init(
                        x: self.monitor.frame.maxX - 1.125,
                        y: self.monitor.frame.maxY - 1.125))
            }
        } else {
            print("Window \(windowId) is already owned by another workspace")
        }
    }
    
    func removeWindow(_ window: AXUIElement) {
        guard let windowNode = self.children.first(
            where: {
                $0.type == .window && ($0 as? WindowNode)?.window == window
            }) as? WindowNode else {
            print("Window not found in workspace")
            return
        }

        guard let windowID = windowNode.systemWindowID else {
            print("Window ID not available")
            return
        }
        
        // Remove window from children list - fixing the implementation
        children.removeAll { node in
            if let node = node as? WindowNode {
                return node.window == window
            }
            return false
        }

        // Remove from ownership tracking
        if let intID = Int(windowID) {
            WindowManager.shared.windowOwnership.removeValue(forKey: intID)
        }
    }

    func activate() {
        print("Activating workspace: \(self.title ?? "Unknown")")
        
        // Deactivate previous workspace if different
        if let currentWorkspace = monitor.activeWorkspace, currentWorkspace.id != self.id {
            currentWorkspace.deactivate()
        }
        
        // Set as active workspace
        monitor.activeWorkspace = self
        
        // Restore window positions
        restoreWindowStates()
        
        print("Activated \(self.title ?? "Unknown")")
    }

    func deactivate() {
        print("Deactivating workspace: \(self.title ?? "Unknown")")
        
        // Save window states
        let windows = self.getAllWindowNodes()
        
        // Clear previous saved states
        savedWindowStates.removeAll()
        
        // Store window states before hiding
        for window in windows {
            if saveWindowState(window) {
                // Move windows off-screen
                window.move(
                    to: .init(
                        x: self.monitor.frame.maxX - 1.125,
                        y: self.monitor.frame.maxY - 1.125))
            } else {
                print("Error saving window state for \(window.title ?? "Unknown")")
            }
        }
    }

    func saveWindowState(_ window: WindowNode) -> Bool {
        guard let position = window.position else {
            print("Error getting position for \(window.title ?? "Unknown")")
            return false
        }
        
        guard let size = window.size else {
            print("Error getting size for \(window.title ?? "Unknown")")
            return false
        }
        
        let title = window.title
        
        // Store the window element directly with its state
        savedWindowStates.append(SavedWindowState(
            window: window.window,
            position: position,
            size: size,
            title: title
        ))
        
        print("Saved state for window \(title ?? "Unknown"): position=\(position), size=\(size)")
        return true
    }

    // Restore the state of all windows in the workspace
    // Restore the state of all windows in the workspace
    private func restoreWindowStates() {
        print("Restoring \(savedWindowStates.count) window states")
        
        // First, process all windows that are already in this workspace
        let currentWindows = getAllWindowNodes()
        
        // Create a mapping of AXUIElements to WindowNodes
        var windowNodeMap: [AXUIElement: WindowNode] = [:]
        for node in currentWindows {
            windowNodeMap[node.window] = node
        }
        
        for savedState in savedWindowStates {
            // Check if the saved window is in this workspace
            if let windowNode = windowNodeMap[savedState.window] {
                // Restore position and size using the WindowNode
                windowNode.resize(to: savedState.size)
                windowNode.move(to: savedState.position)
                print("Restored window \(savedState.title ?? "Unknown") to position=\(savedState.position), size=\(savedState.size)")
            } else {
                // Window not in this workspace, try to set position directly using AX API
                var cgPosition = CGPoint(x: savedState.position.x, y: savedState.position.y)
                var cgSize = CGSize(width: savedState.size.width, height: savedState.size.height)
                
                if let positionValue = AXValueCreate(.cgPoint, &cgPosition),
                   let sizeValue = AXValueCreate(.cgSize, &cgSize) {
                    
                    AXUIElementSetAttributeValue(savedState.window, kAXPositionAttribute as CFString, positionValue)
                    AXUIElementSetAttributeValue(savedState.window, kAXSizeAttribute as CFString, sizeValue)
                    
                    print("Directly restored window \(savedState.title ?? "Unknown") via AX API")
                } else {
                    print("Failed to create AX values for window \(savedState.title ?? "Unknown")")
                }
            }
        }
    }}

// Extension to help with NSPoint and NSSize conversions
extension NSPoint {
    var pointee: CGPoint {
        return CGPoint(x: self.x, y: self.y)
    }
}

extension NSSize {
    var sizeValue: CGSize {
        return CGSize(width: self.width, height: self.height)
    }
}
