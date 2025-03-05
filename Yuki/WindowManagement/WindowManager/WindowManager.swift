//
//  WindowManager.swift
//  Yuki
//
//  Created by Claude AI on 5/3/25.
//

import Foundation
import Cocoa
import SwiftUI
import Combine
import os

/// Main class responsible for window management
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
    
    /// Logger for debugging and performance tracking
    private let logger = Logger(subsystem: "com.frostplexx.Yuki", category: "WindowManager")
    
    /// Accessibility service reference
    private let accessibilityService = AccessibilityService.shared
    
    /// Cancellables for subscription management
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Initialize the system
        initialize()
    }
    
    /// Initialize the window manager system
    private func initialize() {
        // Request accessibility permissions
        AccessibilityService.shared.requestPermission()
        
        // Detect monitors
        detectMonitors()
        
        // Initialize workspaces
        initializeWorkspaces()
        
        // Set up window observation
        setupWindowObservation()
        
        // Initial refresh of windows
        refreshWindows()
        
        // Listen for screen configuration changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .throttle(for: 1.0, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.handleScreenConfigurationChange()
            }
            .store(in: &cancellables)
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
            logger.error("No monitors detected")
        }
    }
    
    /// Handle screen configuration changes (monitor added/removed/changed)
    private func handleScreenConfigurationChange() {
        // Store existing workspaces by monitor ID
        var workspacesByMonitorId: [Int: [Workspace]] = [:]
        for monitor in monitors {
            workspacesByMonitorId[monitor.id] = monitor.workspaces
        }
        
        // Store selected workspace ID
        let selectedWorkspaceId = selectedWorkspace?.id
        
        // Refresh monitors
        detectMonitors()
        
        // Reassign workspaces to monitors
        for (monitorId, monitorWorkspaces) in workspacesByMonitorId {
            // Find the monitor with this ID or use the first available
            if let targetMonitor = monitors.first(where: { $0.id == monitorId }) ?? monitors.first {
                for workspace in monitorWorkspaces {
                    // Clear existing monitor reference
                    workspace.monitor = nil
                    
                    // Add to the target monitor
                    targetMonitor.workspaces.append(workspace)
                    workspace.monitor = targetMonitor
                    
                    // Make active if it was the selected workspace
                    if workspace.id == selectedWorkspaceId {
                        targetMonitor.activeWorkspace = workspace
                        selectedWorkspace = workspace
                    }
                }
            }
        }
        
        // Ensure all monitors have at least one workspace
        for monitor in monitors where monitor.workspaces.isEmpty {
            let workspace = monitor.createWorkspace(name: "Main")
            workspaces.append(workspace)
            
            // If no workspace is selected, select this one
            if selectedWorkspace == nil {
                selectedWorkspace = workspace
            }
        }
        
        // Refresh windows to update layout
        refreshWindows()
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
    
    /// Initialize workspaces for all monitors
    private func initializeWorkspaces() {
        // Try to load workspaces from disk
        do {
            try loadWorkspacesFromDisk()
        } catch {
            // If loading fails, create default workspaces
            createDefaultWorkspaces()
        }
        
        // Update workspaces array
        updateWorkspacesArray()
    }
    
    /// Create default workspaces for each monitor
    private func createDefaultWorkspaces() {
        // Create default workspaces for each monitor
        for monitor in monitors {
            // Create Main workspace
            let mainWorkspace = monitor.createWorkspace(name: "Main")
            
            // Set as selected workspace if none is selected
            if selectedWorkspace == nil {
                selectedWorkspace = mainWorkspace
            }
        }
    }
    
    /// Load workspaces from saved configuration
    private func loadWorkspacesFromDisk() throws {
        // Implementation for loading from disk would go here
        // For now, we'll just create default workspaces
        throw NSError(domain: "com.frostplexx.Yuki", code: 1, userInfo: [NSLocalizedDescriptionKey: "Workspace loading not implemented"])
    }
    
    /// Update the workspaces array from all monitors
    private func updateWorkspacesArray() {
        workspaces = monitors.flatMap { $0.workspaces }
    }
    
    /// Select a workspace as the current workspace
    /// - Parameter workspace: The workspace to select
    func selectWorkspace(_ workspace: Workspace) {
        // Deselect current workspace if it's on a different monitor
        if let currentWorkspace = selectedWorkspace,
           let currentMonitor = currentWorkspace.monitor,
           let newMonitor = workspace.monitor,
           currentMonitor.id != newMonitor.id {
            // Deactivate the current workspace
            currentMonitor.activeWorkspace = nil
        }
        
        // Find which monitor this workspace belongs to
        guard let monitor = workspace.monitor else {
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
    
    // MARK: - Window Management
    
    /// Refreshes the window list and assigns unassigned windows to appropriate workspaces
    func refreshWindows() {
        // Get the current window list
        let visibleWindows = accessibilityService.getAllVisibleWindows()
        
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
            
            // Try to get the window element
            if let window = accessibilityService.getWindowElement(for: CGWindowID(windowId)) {
                // Create a window node
                let windowNode = WindowNode(window: window, systemWindowID: windowId, title: windowInfo["kCGWindowName"] as? String)
                
                // Add to workspace's default container
                targetWorkspace.addWindowToDefaultContainer(windowNode)
                
                // Register ownership
                windowOwnership[windowId] = targetWorkspace.id
                
                // Disable enhanced user interface for better tiling
                accessibilityService.disableEnhancedUserInterface(for: window)
            }
        }
        
        // Apply tiling if not in float mode
        if TilingEngine.shared.currentMode != .float {
            applyCurrentTiling()
        }
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
        if let monitor = workspace.monitor, TilingEngine.shared.currentMode != .float {
            TilingEngine.shared.applyTiling(to: workspace, on: monitor)
        }
    }
    
    // MARK: - Cleanup Functions
    
    /// Clean up workspaces and ensure proper structure
    func cleanupAllWorkspaces() {
        for monitor in monitors {
            for workspace in monitor.workspaces {
                workspace.cleanupStructure()
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
        
        print("\nCurrent Tiling Mode: \(TilingEngine.shared.currentMode.description)")
    }
    
    /// Prints the window tree hierarchy
    private func printWindowTree(node: any Node, indent: Int) {
        let indentStr = String(repeating: "  ", count: indent)
        
        for child in node.children {
            if let windowNode = child as? WindowNode {
                print("\(indentStr)- Window \(windowNode.systemWindowID ?? 0): \(windowNode.title ?? "Untitled")")
            } else if let containerNode = child as? ContainerNode {
                print("\(indentStr)- Container (\(containerNode.type)): \(containerNode.title ?? "Untitled")")
                printWindowTree(node: containerNode, indent: indent + 1)
            }
        }
    }
}

// MARK: - WindowManager Errors

enum WindowManagerError: Error {
    case notImplemented
    case noMonitorsFound
    case workspaceNotFound
    case windowNotFound
}

// MARK: - Monitor Extension for Workspace Management

extension Monitor {
    /// Activates the specified workspace on this monitor
    /// - Parameter workspace: The workspace to activate
    /// - Returns: True if activation was successful
    @discardableResult
    func activateWorkspace(_ workspace: Workspace) -> Bool {
        // Ensure the workspace belongs to this monitor
        guard workspaces.contains(where: { $0.id == workspace.id }) else {
            return false
        }
        
        // Don't do anything if it's already active
        if activeWorkspace?.id == workspace.id {
            return true
        }
        
        // Store current window positions if switching from another workspace
        if let currentWorkspace = activeWorkspace {
            // Hide windows from current workspace
            for windowNode in currentWorkspace.root.getAllWindowNodes() {
                if let window = windowNode.window as? AXUIElement {
                    // Move off-screen to hide
                    let offscreenPoint = NSPoint(x: -10000, y: -10000)
                    AccessibilityService.shared.setPosition(offscreenPoint, for: window)
                }
            }
        }
        
        // Set as active workspace
        activeWorkspace = workspace
        
        // Show windows for new workspace
        for windowNode in workspace.root.getAllWindowNodes() {
            if let window = windowNode.window as AXUIElement? {
                // Apply correct position based on tiling mode
                if TilingEngine.shared.currentMode != .float {
                    // Windows will be positioned by tiling engine
                } else if let position = AccessibilityService.shared.getPosition(for: window),
                          let size = AccessibilityService.shared.getSize(for: window) {
                    // Restore saved position and size
                    let frame = NSRect(origin: position, size: size)
                    AccessibilityService.shared.setFrame(frame, for: window)
                } else {
                    // Default center position if no saved position
                    let defaultSize = NSSize(width: 800, height: 600)
                    let x = (visibleFrame.width - defaultSize.width) / 2 + visibleFrame.minX
                    let y = (visibleFrame.height - defaultSize.height) / 2 + visibleFrame.minY
                    let defaultFrame = NSRect(x: x, y: y, width: defaultSize.width, height: defaultSize.height)
                    AccessibilityService.shared.setFrame(defaultFrame, for: window)
                }
                
                // Bring window to front
                AccessibilityService.shared.raiseWindow(window)
            }
        }
        
        // Apply tiling if needed
        if TilingEngine.shared.currentMode != .float {
            TilingEngine.shared.applyTiling(to: workspace, on: self)
        }
        
        return true
    }
}

// MARK: - Singleton Provider

/// Utility class to provide a singleton instance of the window manager
class WindowManagerProvider {
    /// Shared window manager instance
    static let shared: WindowManager = {
        let manager = WindowManager()
        return manager
    }()
}
