// WindowManager.swift
// Central service for window management

import AppKit
import Foundation
import Combine

/// Central manager for monitors, workspaces, and windows
class WindowManager: ObservableObject {
    // MARK: - Singleton
    
    /// Shared instance
    static let shared: WindowManager = WindowManager()
    
    // MARK: - Published Properties
    
    /// All detected monitors
    @Published var monitors: [Monitor] = []
    
    // MARK: - Window Management
    
    /// Maps window IDs to workspace IDs for ownership tracking
    @Published private(set) var windowOwnership: [CGWindowID: UUID] = [:]
    
    /// Service for discovering windows
    let windowDiscovery = WindowDiscoveryService()
    
    /// Operations queue for parallel window operations
    private let operationsQueue = DispatchQueue(
        label: "com.yuki.windowOperations",
        qos: .userInteractive,
        attributes: .concurrent
    )
    
    /// Concurrent operations semaphore
    private let operationsSemaphore = DispatchSemaphore(value: 8)
    
    /// Caches for improved performance
    private var workspaceCache: [UUID: WorkspaceNode] = [:]
    private var windowNodeCache: [CGWindowID: WindowNode] = [:]
    
    // Add cache limits
    private let maxCacheSize = 100
    var isActive = true
    
    // MARK: - Initialization
    
    private init() {
        detectMonitors()
        
        // Listen for sleep/wake notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSleepWake),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSleepWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    // MARK: - Monitor Management
    
    /// Detect and initialize all connected monitors
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
        
        // If no monitors found, log an error
        if monitors.isEmpty {
            print("Error: No monitors detected")
        }
    }
    
    /// Get the monitor containing the specified point
    func monitorContaining(point: NSPoint) -> Monitor? {
        return monitors.first { monitor in
            NSPointInRect(point, monitor.frame)
        }
    }
    
    /// Get the monitor containing the mouse cursor
    var monitorWithMouse: Monitor? {
        let mouseLocation = NSEvent.mouseLocation
        return monitorContaining(point: mouseLocation)
    }
    
    // MARK: - Window Discovery & Assignment
    
    /// Discover all visible windows and assign them to appropriate workspaces
    func discoverAndAssignWindows() {
        // Get all visible windows
        let visibleWindows = windowDiscovery.getAllVisibleWindows()
        
        for windowInfo in visibleWindows {
            guard let windowID = windowInfo["kCGWindowNumber"] as? Int,
                  let ownerPID = windowInfo["kCGWindowOwnerPID"] as? Int32,
                  let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat
            else { continue }
            
            // Skip windows that are already assigned
            if windowOwnership[CGWindowID(windowID)] != nil {
                continue
            }
            
            // Find which monitor contains this window
            let windowPosition = NSPoint(x: x, y: y)
            let targetMonitor = monitorContaining(point: windowPosition)
            
            // Get the active workspace for this monitor
            guard let targetMonitor = targetMonitor,
                  let targetWorkspace = targetMonitor.activeWorkspace
            else { continue }
            
            // Try to get the window element
            if let window = windowDiscovery.getWindowElement(for: CGWindowID(windowID)) {
                // Let the workspace adopt the window
                targetWorkspace.adoptWindow(window)
            }
        }
    }
    
    /// Register window ownership
    func registerWindowOwnership(windowID: CGWindowID, workspaceID: UUID) {
        windowOwnership[windowID] = workspaceID
    }
    
    /// Unregister window ownership
    func unregisterWindowOwnership(windowID: CGWindowID) {
        windowOwnership.removeValue(forKey: windowID)
        windowNodeCache.removeValue(forKey: windowID)
    }
    
    /// Remove windows for a specific application
    func removeWindowsForApp(_ pid: pid_t) {
        // For each monitor and workspace
        for monitor in monitors {
            for workspace in monitor.workspaces {
                // Get all window nodes in this workspace
                let windowNodes = workspace.getAllWindowNodes()
                
                // Find windows belonging to the app
                for windowNode in windowNodes {
                    if getPID(for: windowNode.window) == pid {
                        // Remove from window ownership
                        if let windowID = windowNode.systemWindowID {
                            unregisterWindowOwnership(windowID: windowID)
                        }
                        
                        // Remove from workspace
                        workspace.removeChild(windowNode)
                    }
                }
            }
        }
    }
    
    // MARK: - Workspace & Window Lookup
    
    /// Find a workspace by its ID
    func findWorkspace(byID id: UUID) -> WorkspaceNode? {
        // Only perform lookups if active
        guard isActive else { return nil }
        
        if let cached = workspaceCache[id] {
            return cached
        }
        
        for monitor in monitors {
            if let workspace = monitor.workspaces.first(where: { $0.id == id }) {
                updateWorkspaceCache(id: id, workspace: workspace)
                return workspace
            }
        }
        
        return nil
    }
    
    /// Find a window node by its system ID
    func findWindowNode(byID windowID: CGWindowID) -> WindowNode? {
        // Only perform lookups if active
        guard isActive else { return nil }
        
        if let cached = windowNodeCache[windowID] {
            return cached
        }
        
        // Check by ownership
        if let workspaceID = windowOwnership[windowID],
           let workspace = findWorkspace(byID: workspaceID),
           let windowNode = workspace.findWindowNode(withID: windowID) {
            updateWindowNodeCache(windowID: windowID, node: windowNode)
            return windowNode
        }
        
        for monitor in monitors {
            for workspace in monitor.workspaces {
                if let windowNode = workspace.findWindowNode(withID: windowID) {
                    updateWindowNodeCache(windowID: windowID, node: windowNode)
                    return windowNode
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Tiling Commands
    
    /// Arrange windows in the current workspace horizontally
    func arrangeCurrentWorkspaceHorizontally() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        workspace.setTilingMode("hstack")
    }
    
    /// Arrange windows in the current workspace vertically
    func arrangeCurrentWorkspaceVertically() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        workspace.setTilingMode("vstack")
    }
    
    /// Arrange windows in the current workspace using binary space partitioning
    func arrangeCurrentWorkspaceBSP() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        workspace.setTilingMode("bsp")
    }
    
    /// Set the current workspace to floating mode
    func floatCurrentWorkspace() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        workspace.setTilingMode("float")
    }
    
    func arrangeCurrentWorkspaceStacked(){
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        workspace.setTilingMode("zstack")
    }
    
    /// Cycle tiling mode in the current workspace
    func cycleTilingMode() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        workspace.cycleToNextTilingMode()
    }
    
    // MARK: - Focus Control
    
    /// Focus the next window in the current workspace
    func focusNextWindow() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        
        let windows = workspace.getVisibleWindowNodes()
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
        
        let windows = workspace.getVisibleWindowNodes()
        guard !windows.isEmpty else { return }
        
        // Find currently focused window
        let focusedWindowIndex = windows.firstIndex { window in
            window.window.get(Ax.isFocused) ?? false
        } ?? 0
        
        // Focus the previous window
        let prevIndex = (focusedWindowIndex - 1 + windows.count) % windows.count
        windows[prevIndex].focus()
    }
    
    // MARK: - Utility Functions
    
    /// Get the process ID for an accessibility element
    func getPID(for element: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return pid
    }
    
    /// Print debug information about monitors, workspaces, and windows
    func printDebugInfo() {
        print("\n===== WINDOW MANAGER DEBUG INFO =====")
        print("Monitor with mouse: \(monitorWithMouse?.name ?? "None")")
        
        for (i, monitor) in monitors.enumerated() {
            print("\n== Monitor \(i): \(monitor.name) ==")
            print("Active Workspace: \(monitor.activeWorkspace?.title ?? "None")")
            
            for (j, workspace) in monitor.workspaces.enumerated() {
                print("  Workspace \(j): \(workspace.title ?? "Untitled")")
                print("  Tiling Mode: \(workspace.tilingEngine.currentLayoutType.description)")
                
                let windows = workspace.getAllWindowNodes()
                print("  Windows: \(windows.count)")
                
                for (k, window) in windows.enumerated() {
                    let floatStatus = window.isFloating ? "Float" : "Tile"
                    let minimizedStatus = window.isMinimized ? "Minimized" : "Normal"
                    print("    [\(k)] \(window.title ?? "Untitled") - \(floatStatus), \(minimizedStatus)")
                }
            }
        }
        
        print("\nWindow Ownership: \(windowOwnership.count) windows")
        print("====================================\n")
    }
    
    // Add sleep/wake handler
    @objc private func handleSleepWake(notification: Notification) {
        if notification.name == NSWorkspace.willSleepNotification {
            isActive = false
            clearCaches()
        } else if notification.name == NSWorkspace.didWakeNotification {
            isActive = true
            detectMonitors()
        }
    }
    
    // Add cache management
    func clearCaches() {
        workspaceCache.removeAll()
        windowNodeCache.removeAll()
    }
    
    // Modify cache updates to respect size limits
    private func updateWindowNodeCache(windowID: CGWindowID, node: WindowNode) {
        if windowNodeCache.count >= maxCacheSize {
            windowNodeCache.removeValue(forKey: windowNodeCache.keys.first!)
        }
        windowNodeCache[windowID] = node
    }
    
    private func updateWorkspaceCache(id: UUID, workspace: WorkspaceNode) {
        if workspaceCache.count >= maxCacheSize {
            workspaceCache.removeValue(forKey: workspaceCache.keys.first!)
        }
        workspaceCache[id] = workspace
    }
}
