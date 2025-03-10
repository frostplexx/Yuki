// Monitor.swift
// Monitor representation and management

import Cocoa
import Foundation

/// Represents a physical display in the system
class Monitor: Identifiable, ObservableObject {
    // MARK: - Properties
    
    /// Unique identifier for this monitor
    let id: Int
    
    /// The complete frame of the monitor
    let frame: NSRect
    
    /// The visible frame (excludes Dock, menu bar, etc.)
    let visibleFrame: NSRect
    
    /// Human-readable name of the monitor
    let name: String
    
    /// Workspaces available on this monitor
    @Published var workspaces: [WorkspaceNode] = []
    
    /// Currently active workspace on this monitor
    @Published var activeWorkspace: WorkspaceNode?
    
    // MARK: - Computed Properties
    
    /// The width of the monitor in points
    var width: CGFloat { frame.width }
    
    /// The height of the monitor in points
    var height: CGFloat { frame.height }
    
    /// Whether this is the main monitor (contains menu bar)
    var isMain: Bool {
        if let mainScreen = NSScreen.main {
            return NSEqualRects(frame, mainScreen.frame)
        }
        return false
    }
    
    /// Whether this monitor contains the mouse pointer
    var hasMousePointer: Bool {
        let mouseLocation = NSEvent.mouseLocation
        return NSPointInRect(mouseLocation, frame)
    }
    
    // MARK: - Initialization
    
    /// Initialize a new monitor
    init(id: Int, frame: NSRect, visibleFrame: NSRect, name: String) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.name = name
        
        // Create default workspaces
        initializeDefaultWorkspaces()
    }
    
    // MARK: - Workspace Management
    
    /// Initialize default workspaces for this monitor
    private func initializeDefaultWorkspaces() {
        // Create a default workspace
        let defaultWorkspace = WorkspaceNode(title: "Default", monitor: self)
        workspaces.append(defaultWorkspace)
        
        // Create secondary workspace
        let secondWorkspace = WorkspaceNode(title: "Secondary", monitor: self)
        workspaces.append(secondWorkspace)
        
        // Set the first workspace as active
        activeWorkspace = workspaces.first
    }
    
    /// Create a new workspace
    @discardableResult
    func createWorkspace(name: String) -> WorkspaceNode {
        let workspace = WorkspaceNode(title: name, monitor: self)
        workspaces.append(workspace)
        return workspace
    }
    
    /// Remove a workspace
    @discardableResult
    func removeWorkspace(_ workspace: WorkspaceNode) -> Bool {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else {
            return false
        }
        
        // Can't remove the last workspace
        if workspaces.count <= 1 {
            return false
        }
        
        // Move windows to another workspace if this was active
        if activeWorkspace?.id == workspace.id {
            // Get all windows in this workspace
            let windowNodes = workspace.getAllWindowNodes()
            
            // Choose another workspace to move windows to
            let targetIndex = index > 0 ? index - 1 : (index + 1 < workspaces.count ? index + 1 : nil)
            
            if let targetIndex = targetIndex {
                let targetWorkspace = workspaces[targetIndex]
                
                // Move all windows to the target workspace
                for windowNode in windowNodes {
                    workspace.removeChild(windowNode)
                    targetWorkspace.addChild(windowNode)
                    
                    // Update ownership if needed
                    if let windowID = windowNode.systemWindowID {
                        WindowManager.shared.registerWindowOwnership(windowID: windowID, workspaceID: targetWorkspace.id)
                    }
                }
                
                // Set the target workspace as active
                activeWorkspace = targetWorkspace
            }
        }
        
        // Remove the workspace
        workspaces.remove(at: index)
        return true
    }
    
    /// Check if a point is within this monitor's frame
    func contains(point: NSPoint) -> Bool {
        return NSPointInRect(point, frame)
    }
}

// MARK: - Equatable & Hashable Conformance

extension Monitor: Equatable, Hashable {
    static func == (lhs: Monitor, rhs: Monitor) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
