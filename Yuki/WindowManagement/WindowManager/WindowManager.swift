//
//  WindowManager.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa
import SwiftUICore
import ApplicationServices

class WindowManager: ObservableObject {
    // MARK: - Properties
    
    /// List of detected monitors
    @Published var monitors: [Monitor] = []
    
    /// Currently selected workspace
    @Published var selectedWorkspace: Workspace?
    
    /// All workspaces across all monitors
    @Published var workspaces: [Workspace] = []
    
    /// Maps window IDs to workspace IDs for tracking ownership
    @Published var windowOwnership: [Int: UUID] = [:]
    
    // MARK: - Initialization
    
    init() {
        // Detect monitors (if not already done)
        if monitors.isEmpty {
            detectMonitors()
        }
        
        // Initialize workspaces (if not already done)
        if workspaces.isEmpty {
            do {
                try loadWorkspacesFromDisk()
            } catch {
                initDefaultWorkspaces()
            }
        }
        
        // Initialize tiling
        initializeTiling()
        
        // Initialize auto-tiling
        initializeAutoTiling()
        
        // Initialize window tracking
        initializeWindowTracking()
        
        // Initial refresh of windows
        refreshWindows()
    }
    
    // MARK: - Monitor Management
    
    /// Detects and initializes all connected monitors
    func detectMonitors() {
        // Clear existing monitors
        monitors.removeAll()
        
        // Get all screens from NSScreen
        let screens = NSScreen.screens
        
        for (index, screen) in screens.enumerated() {
            let monitor = Monitor(
                id: index,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                name: screen.localizedName
            )
            monitors.append(monitor)
        }
        
        // If no monitors found, this is an error condition
        if monitors.isEmpty {
            print("Error: No monitors detected")
        }
    }
    
    /// Returns the monitor that contains the specified point
    func monitorContaining(point: NSPoint) -> Monitor? {
        return monitors.first { $0.contains(point: point) }
    }
    
    /// Returns the monitor containing the mouse cursor
    var monitorWithMouse: Monitor? {
        let mouseLocation = NSEvent.mouseLocation
        return monitorContaining(point: mouseLocation)
    }
    
    // MARK: - Workspace Management
    
    /// Select a workspace as the current workspace
    /// - Parameter workspace: The workspace to select
    func selectWorkspace(_ workspace: Workspace) {
        // First, find which monitor this workspace belongs to
        guard let monitor = monitors.first(where: { $0.workspaces.contains(where: { $0.id == workspace.id }) }) else {
            return
        }
        
        // Activate this workspace on its monitor
        monitor.activateWorkspace(workspace)
        
        // Set as selected workspace
        selectedWorkspace = workspace
    }
    
    /// Creates a new workspace with the given name on the specified monitor
    func createNewWorkspace(name: String, on monitor: Monitor? = nil) {
        let targetMonitor = monitor ?? monitorWithMouse ?? monitors.first
        guard let targetMonitor = targetMonitor else { return }
        
        let newWorkspace = targetMonitor.createWorkspace(name: name)
        workspaces.append(newWorkspace)
        
        // If no workspace is selected, select this one
        if selectedWorkspace == nil {
            selectedWorkspace = newWorkspace
        }
    }
    
    /// Initializes default workspaces for each monitor
    private func initDefaultWorkspaces() {
        // Create default workspaces for each monitor
        for monitor in monitors {
            let mainWorkspace = monitor.createWorkspace(name: "Main")
            workspaces.append(mainWorkspace)
            
            // Add a second workspace for testing
            let secondWorkspace = monitor.createWorkspace(name: "Test")
            workspaces.append(secondWorkspace)
        }
        
        // Set default selected workspace if we have any
        if !workspaces.isEmpty {
            selectedWorkspace = workspaces.first
        }
    }
    
    /// Load workspaces from saved configuration
    private func loadWorkspacesFromDisk() throws {
        // TODO: implement workspace loading from disk
        throw WindowManagerError.notImplemented
    }
    
    // MARK: - Window Management
    
    /// Refreshes the window list and assigns unassigned windows to appropriate workspaces
    func refreshWindows() {
        let options = CGWindowListOption(
            arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        
        guard let windowList = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]]
        else { return }
        
        let visibleWindows = windowList.filter {
            ($0["kCGWindowLayer"] as? Int) == 0
        }
        
        for windowInfo in visibleWindows {
            guard let windowId = windowInfo["kCGWindowNumber"] as? Int,
                  let ownerPID = windowInfo["kCGWindowOwnerPID"] as? Int32,
                  let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat
            else { continue }
            
            // Skip windows that are already assigned
            if windowOwnership[windowId] != nil {
                continue
            }
            
            // Find which monitor contains this window
            let windowPosition = NSPoint(x: x, y: y)
            let targetMonitor = monitorContaining(point: windowPosition) ?? monitors.first
            
            // Get the active workspace for this monitor
            guard let targetMonitor = targetMonitor,
                  let targetWorkspace = targetMonitor.activeWorkspace ?? targetMonitor.workspaces.first
            else { continue }
            
            // Get the underlying AXUIElement for this window
            if let window = getWindowElement(for: ownerPID, windowId: windowId) {
                assignWindowToContainer(
                    window: window,
                    windowId: windowId,
                    title: windowInfo["kCGWindowName"] as? String,
                    workspace: targetWorkspace
                )
            }
        }
        
        // After refreshing, apply tiling if auto-tiling is enabled
        if autoTilingController.isAutoTilingEnabled() {
            applyCurrentTiling()
        }
    }
    
    /// Gets the accessibility element for a window
    private func getWindowElement(for pid: Int32, windowId: Int) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        
        // Get all windows for this application
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement]
        else { return nil }
        
        // Find the window with the matching ID
        for window in windows {
            if let windowIdValue = window.containingWindowId(), windowIdValue == CGWindowID(windowId) {
                return window
            }
        }
        
        return nil
    }
    
    /// Assigns a window to a workspace's default container
    private func assignWindowToContainer(window: AXUIElement, windowId: Int, title: String? = nil, workspace: Workspace) {
        // Create window node
        let windowNode = WindowNode(window: window, systemWindowID: windowId, title: title)
        
        // Disable enhanced user interface for this window
        window.set(Ax.enhancedUserInterfaceAttr, false)
        
        // Get the default container for the workspace
        let container = workspace.defaultContainer
        
        // Add to container
        var mutableContainer = container
        mutableContainer.append(windowNode)
        
        // Register ownership
        windowOwnership[windowId] = workspace.id
    }
    
    /// Moves a window to a specific workspace
    func moveWindow(windowId: Int, to workspace: Workspace) throws {
        // Find the source workspace
        guard let sourceWorkspaceId = windowOwnership[windowId],
              let sourceWorkspace = workspaces.first(where: { $0.id == sourceWorkspaceId }),
              let windowNode = sourceWorkspace.findWindowNode(systemWindowID: windowId)
        else {
            throw WindowManagerError.windowNotFound
        }
        
        // Remove from current parent
        if let parent = windowNode.parent {
            var mutableParent = parent
            mutableParent.remove(windowNode)
        }
        
        // Add to target workspace's default container
        workspace.addWindowToDefaultContainer(windowNode)
        
        // Update ownership
        windowOwnership[windowId] = workspace.id
        
        // Apply tiling if needed
        if autoTilingController.isAutoTilingEnabled() {
            if let monitor = workspace.monitor {
                TilingManager.shared.applyTiling(to: workspace, on: monitor)
            }
        }
    }
    
    // MARK: - Debug Helpers
    
    /// Prints debug information about the window manager state
    func printDebugInfo() {
        print("\n=== Window Manager Debug Info ===")
        print("Monitors: \(monitors.count)")
        
        for (i, monitor) in monitors.enumerated() {
            print("\nMonitor \(i): \(monitor.name) (\(monitor.frame.width)x\(monitor.frame.height))")
            print("Workspaces: \(monitor.workspaces.count)")
            
            for workspace in monitor.workspaces {
                print("\n  Workspace: \(workspace.displayName) (\(workspace.id))")
                print("  Window Tree:")
                printWindowTree(node: workspace.root, indent: 2)
            }
        }
        
        print("\nWindow Ownership Map:")
        for (windowId, workspaceId) in windowOwnership {
            if let workspace = workspaces.first(where: { $0.id == workspaceId }) {
                print("  Window \(windowId) → Workspace \(workspace.displayName)")
            }
        }
        
        print("\nCurrent Tiling Mode: \(TilingManager.shared.getCurrentMode().description)")
        print("Auto-Tiling: \(autoTilingController.isAutoTilingEnabled() ? "Enabled" : "Disabled")")
    }
    
    /// Prints the window tree hierarchy
    private func printWindowTree(node: any Node, indent: Int) {
        let indentStr = String(repeating: "  ", count: indent)
        
        for child in node.children {
            if let windowNode = child as? WindowNode {
                print("\(indentStr)- Window \(windowNode.systemWindowID ?? 0): \(windowNode.title ?? "Untitled")")
            } else if let groupNode = child as? ContainerNode {
                print("\(indentStr)- Group (\(groupNode.type)): \(groupNode.title ?? "Untitled")")
                printWindowTree(node: groupNode, indent: indent + 1)
            }
        }
    }
}

