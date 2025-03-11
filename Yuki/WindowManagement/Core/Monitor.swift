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
        
        // Workspaces will be initialized from settings or with defaults
        loadWorkspacesFromSettings()
    }
    
    // MARK: - Workspace Management
    
    /// Load workspaces from settings or create defaults
    private func loadWorkspacesFromSettings() {
        let settingsManager = SettingsManager.shared
        let configuredWorkspaces = settingsManager.getWorkspaces(forMonitorID: id)
        
        if !configuredWorkspaces.isEmpty {
            // Create workspaces from saved configurations
            for config in configuredWorkspaces {
                if let uuid = UUID(uuidString: config.id) {
                    let workspace = WorkspaceNode(
                        id: uuid,
                        title: config.name,
                        monitor: self
                    )
                    
                    // Set tiling type
                    workspace.tilingEngine.setLayoutType(named: config.layoutType)
                    
                    // Add to workspaces list
                    workspaces.append(workspace)
                }
            }
            
            // Set first workspace as active by default
            activeWorkspace = workspaces.first
        } else {
            // Create default workspaces if none exist
            initializeDefaultWorkspaces()
        }
    }
    
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
        
        // Save to settings
        let settingsManager = SettingsManager.shared
        
        // Add both workspaces to settings
        settingsManager.addWorkspace(
            name: "Default",
            monitorID: id,
            layoutType: "bsp"
        )
        
        settingsManager.addWorkspace(
            name: "Secondary",
            monitorID: id,
            layoutType: "hstack"
        )
    }
    
    /// Create a new workspace
    @discardableResult
    func createWorkspace(name: String, layoutType: String = "bsp") -> WorkspaceNode {
        // First add to settings to generate a UUID
        let config = SettingsManager.shared.addWorkspace(
            name: name,
            monitorID: id,
            layoutType: layoutType
        )
        
        // Create the workspace with the assigned UUID
        let workspace = WorkspaceNode(
            id: config.uuid,
            title: name,
            monitor: self
        )
        
        // Set layout type
        workspace.tilingEngine.setLayoutType(named: layoutType)
        
        // Add to workspaces
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
        
        // Remove from settings
        SettingsManager.shared.removeWorkspace(withID: workspace.id.uuidString)
        
        // Remove the workspace
        workspaces.remove(at: index)
        return true
    }
    
    /// Switch to the next workspace
    func activateNextWorkspace() {
        guard !workspaces.isEmpty else { return }
        
        let currentIndex = workspaces.firstIndex { $0.id == activeWorkspace?.id } ?? -1
        let nextIndex = (currentIndex + 1) % workspaces.count
        
        workspaces[nextIndex].activate()
    }
    
    /// Switch to the previous workspace
    func activatePreviousWorkspace() {
        guard !workspaces.isEmpty else { return }
        
        let currentIndex = workspaces.firstIndex { $0.id == activeWorkspace?.id } ?? 0
        let prevIndex = (currentIndex - 1 + workspaces.count) % workspaces.count
        
        workspaces[prevIndex].activate()
    }
    
    /// Activate a workspace by index
    func activateWorkspace(at index: Int) {
        guard index >= 0 && index < workspaces.count else { return }
        
        workspaces[index].activate()
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
