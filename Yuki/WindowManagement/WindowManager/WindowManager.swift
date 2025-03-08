//
//  WindowManager.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import AppKit
import Foundation
import Combine

class WindowManager: ObservableObject {

    static let shared: WindowManager = WindowManager()

    @Published var monitors: [Monitor] = []
    
    var windowCache: [CGWindowID: AXUIElement] = [:]

    let windowDiscovery = WindowDiscoveryService()

    /// Maps window IDs to workspace IDs for tracking ownership
    @Published var windowOwnership: [Int: UUID] = [:]

    /// Queue for parallel window operations
    let windowOperationsQueue = DispatchQueue(
        label: "com.yuki.windowOperations", 
        attributes: .concurrent
    )
    
    /// Semaphore to limit concurrent operations to avoid overwhelming the system
    let operationsSemaphore = DispatchSemaphore(value: 8)

    private init() {
        detectMonitors()
        
        // Initialize and start the unified window observer service
        // Note: We don't call start() here because it will be started in AppDelegate
        // to ensure proper initialization order and main thread execution
        
        discoverAndAssignWindows()
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
            print("No monitors detected")
        }
    }

    /// Handle screen configuration changes (monitor added/removed/changed)
    private func handleScreenConfigurationChange() {
        // Refresh monitors
        detectMonitors()
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

    // MARK: - Window Management

    /// Discover windows and distribute them to appropriate workspaces
    /// Call this method after initialization to avoid deadlocks
    func discoverAndAssignWindows() {
        DispatchQueue.main.async {
            // Get all visible windows using our window discovery service
            let visibleWindows = self.windowDiscovery.getAllVisibleWindows()

            for windowInfo in visibleWindows {
                guard let windowId = windowInfo["kCGWindowNumber"] as? Int,
                    let ownerPID = windowInfo["kCGWindowOwnerPID"] as? Int32,
                    let bounds = windowInfo["kCGWindowBounds"]
                        as? [String: Any],
                    let x = bounds["X"] as? CGFloat,
                    let y = bounds["Y"] as? CGFloat
                else { continue }

                // Skip windows that are already assigned
                if self.windowOwnership[windowId] != nil {
                    continue
                }

                // Find which monitor contains this window
                let windowPosition = NSPoint(x: x, y: y)
                let targetMonitor = self.monitorContaining(
                    point: windowPosition)

                // Get the active workspace for this monitor
                guard let targetMonitor = targetMonitor,
                    let targetWorkspace = targetMonitor.activeWorkspace
                else { continue }

                // Try to get the window element
                if let window = self.windowDiscovery.getWindowElement(
                    for: CGWindowID(windowId))
                {
                    // Let the workspace adopt the window
                    targetWorkspace.adoptWindow(window)

                    // Register ownership
                    self.windowOwnership[windowId] = targetWorkspace.id
                }
            }

            // Print debug info after assigning windows
            //            self.printDebugInfo()
        }
    }

    // MARK: - Window List Refresh

    /// Refresh the windows list - check for closed/hidden windows and remove them
    func refreshWindowsList() {
        DispatchQueue.main.async {
            // Get all currently visible windows
            let visibleWindows = self.windowDiscovery.getAllVisibleWindows()
            let visibleWindowIds = Set(
                visibleWindows.compactMap { $0["kCGWindowNumber"] as? Int })

            // Process each monitor and workspace
            for monitorIndex in 0..<self.monitors.count {
                for workspaceIndex
                    in 0..<self.monitors[monitorIndex].workspaces.count
                {
                    // Get a direct reference to the workspace
                    var workspace = self.monitors[monitorIndex].workspaces[
                        workspaceIndex]

                    // Get all window nodes in the workspace
                    let windowNodes = workspace.getAllWindowNodes()

                    // Remove windows that are no longer visible
                    for windowNode in windowNodes {
                        // Convert the windowNode's system ID to an integer for comparison
                        if let systemWindowId = windowNode.systemWindowID,
                            let windowId = Int(systemWindowId),
                            !visibleWindowIds.contains(windowId)
                        {

                            // Remove from ownership tracking
                            self.windowOwnership.removeValue(forKey: windowId)

                            // Remove from workspace
                            workspace.remove(windowNode)

                            print(
                                "Removed closed/hidden window \(windowId) from workspace \(workspace.title ?? "Untitled")"
                            )
                        }
                    }
                }
            }

            // Discover and assign any new windows
            self.discoverAndAssignWindows()
        }
    }

    /// Remove windows for a specific app from all workspaces
    func removeWindowsForApp(_ pid: pid_t) {
        DispatchQueue.main.async {
            // For each monitor, access its workspaces directly
            for monitorIndex in 0..<self.monitors.count {
                for workspaceIndex
                    in 0..<self.monitors[monitorIndex].workspaces.count
                {
                    // Get a direct reference to the mutable workspace
                    var workspace = self.monitors[monitorIndex].workspaces[
                        workspaceIndex]

                    // Get all window nodes in the workspace
                    let windowNodes = workspace.getAllWindowNodes()

                    // Find windows belonging to the app
                    for windowNode in windowNodes {
                        if self.getPID(for: windowNode.window) == pid {
                            // Remove from window ownership tracking
                            if let windowId = Int(
                                windowNode.systemWindowID ?? "-1")
                            {
                                self.windowOwnership.removeValue(
                                    forKey: windowId)
                            }

                            // Remove from workspace using direct reference
                            workspace.remove(windowNode)
                          
                        }
                    }
                }
            }

            // Update debug info
            self.printDebugInfo()
        }
    }
}
