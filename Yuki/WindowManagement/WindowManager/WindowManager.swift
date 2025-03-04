//
//  WindowManager.swift
//  Yuki
//
//  Created by Claude AI on 6/3/25.
//

import Foundation
import Cocoa
import SwiftUI
import Combine
import os
import ObjectiveC

/// Main class responsible for window management
class WindowManager: ObservableObject, WindowObserverDelegate {
    // MARK: - Published Properties
    
    static let shared: WindowManager =  WindowManager()

    /// List of detected monitors
    @Published var monitors: [Monitor] = []
    
    /// Currently selected workspace
    @Published var selectedWorkspace: Workspace?
    
    /// All workspaces across all monitors
    @Published var workspaces: [Workspace] = []
    
    /// Maps window IDs to workspace IDs for tracking ownership
    @Published var windowOwnership: [Int: UUID] = [:]
    
    // MARK: - Private Properties
    
    /// Logger for debugging and performance tracking
    private let logger = Logger(subsystem: "com.frostplexx.Yuki", category: "WindowManager")
    
    /// Accessibility service reference
    private let accessibilityService = AccessibilityService.shared
    
    /// Cancellables for subscription management
    private var cancellables = Set<AnyCancellable>()
    
    /// Window observer instance
    var windowObserver: WindowObserver?
    
    /// Dictionary storing pinned window positions
    private var pinnedWindowPositions: [Int: NSRect] = [:]
    
    /// Whether window pinning is enabled
    private var _windowPinningEnabled: Bool = false
    
    /// Timer for pinning
    private var pinningTimer: Timer?
    
    /// Whether window pinning is enabled
    var windowPinningEnabled: Bool {
        get { return _windowPinningEnabled }
        set { _windowPinningEnabled = newValue }
    }
    
    // MARK: - Initialization
    
    private init() {
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
        
        // Enhanced initialization with improved window detection
        enhancedInitialization()
        
        // Listen for screen configuration changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .throttle(for: 1.0, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.handleScreenConfigurationChange()
            }
            .store(in: &cancellables)
    }
    
    /// Enhanced initialization with improved window detection
    func enhancedInitialization() {
        // First, ensure we have accessibility permissions
        if !AccessibilityService.shared.hasAccessibilityPermission {
            AccessibilityService.shared.requestPermission()
        }
        
        // Set up window observation with enhanced detection
        setupEnhancedWindowObservation()
        
        // Enable window pinning for the BSP and stack tiling modes
        if TilingEngine.shared.currentMode != .float {
            enableWindowPinning()
        }
        
        // Initial tiling application
        applyCurrentTilingWithPinning()
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
    
    // MARK: - Window Event Handling
    
    /// Setup enhanced window observation
    private func setupEnhancedWindowObservation() {
        // Create and store a window observer
        windowObserver = WindowObserver(delegate: self)
        
        // Start observing
        windowObserver?.startObserving()
        
        // Apply enhanced detection methods
        windowObserver?.enhanceInitialWindowDetection()
        windowObserver?.forceWindowRefresh()
    }
    
    /// Set up window observation
    func setupWindowObservation() {
        // Create and store a window observer
        windowObserver = WindowObserver(delegate: self)
        
        // Start observing
        windowObserver?.startObserving()
    }
    
    /// Handle window events from observer
    func handleWindowEvent(_ event: WindowEvent) {
        switch event.type {
        case .created:
            if let windowId = event.windowId, let windowInfo = event.windowInfo {
                handleNewWindow(windowId: Int(windowId), windowInfo: windowInfo)
                
                // Update pinning if enabled
                if windowPinningEnabled,
                   let windowElement = AccessibilityService.shared.getWindowElement(for: windowId),
                   let frame = AccessibilityService.shared.getPosition(for: windowElement).map({ position in
                       NSRect(origin: position,
                              size: AccessibilityService.shared.getSize(for: windowElement) ?? NSSize(width: 800, height: 600))
                   }) {
                    updatePinnedPosition(for: Int(windowId), frame: frame)
                }
            }
            
        case .closed:
            if let windowId = event.windowId {
                handleWindowClosed(windowId: Int(windowId))
                
                // Remove from pinned windows if needed
                if windowPinningEnabled {
                    pinnedWindowPositions.removeValue(forKey: Int(windowId))
                }
            }
            
        case .moved:
            if let windowId = event.windowId {
                if windowPinningEnabled {
                    handleWindowMovedForPinning(windowId: Int(windowId))
                } else if TilingEngine.shared.currentMode != .float {
                    debounceApplyTiling()
                }
            }
            
        case .resized:
            if let windowId = event.windowId {
                if windowPinningEnabled {
                    // Restore pinned size
                    if let pinnedFrame = pinnedWindowPositions[Int(windowId)],
                       let windowElement = AccessibilityService.shared.getWindowElement(for: windowId) {
                        AccessibilityService.shared.setSize(pinnedFrame.size, for: windowElement)
                    }
                } else if TilingEngine.shared.currentMode != .float {
                    debounceApplyTiling()
                }
            }
            
        case .appActivated, .appTerminated, .spaceChanged:
            // Force a complete refresh for major system events
            windowObserver?.forceWindowRefresh()
            
            // If not in float mode, reapply tiling with pinning
            if TilingEngine.shared.currentMode != .float {
                applyCurrentTilingWithPinning()
            }
            
        default:
            break
        }
    }
    
    /// Handle a new window being detected
    private func handleNewWindow(windowId: Int, windowInfo: [String: Any]) {
        guard let pid = windowInfo["kCGWindowOwnerPID"] as? pid_t,
              let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
              let x = bounds["X"] as? CGFloat,
              let y = bounds["Y"] as? CGFloat else {
            return
        }
        
        // Skip windows that are already assigned
        if windowOwnership[windowId] != nil {
            return
        }
        
        // Find which monitor contains this window
        let windowPosition = NSPoint(x: x, y: y)
        let targetMonitor = monitorContaining(point: windowPosition) ?? monitors.first
        
        // Get the active workspace for this monitor
        guard let targetMonitor = targetMonitor,
              let targetWorkspace = targetMonitor.activeWorkspace ?? targetMonitor.workspaces.first else {
            return
        }
        
        // Get the underlying AXUIElement for this window
        if let window = AccessibilityService.shared.getWindowElement(for: CGWindowID(windowId)) {
            assignWindowToWorkspace(
                window: window,
                windowId: windowId,
                title: windowInfo["kCGWindowName"] as? String,
                workspace: targetWorkspace
            )
        }
    }
    
    /// Assign a window to a workspace
    private func assignWindowToWorkspace(window: AXUIElement, windowId: Int, title: String?, workspace: Workspace) {
        // Create a window node
        let windowNode = WindowNode(window: window, systemWindowID: windowId, title: title)
        
        // Disable enhanced user interface for better tiling
        accessibilityService.disableEnhancedUserInterface(for: window)
        
        // Add to workspace
        workspace.addWindowToDefaultContainer(windowNode)
        
        // Register ownership
        windowOwnership[windowId] = workspace.id
        
        // Apply tiling if needed
        if TilingEngine.shared.currentMode != .float {
            debounceApplyTiling()
        }
    }
    
    /// Handle window closed event
    func handleWindowClosed(windowId: Int) {
        // Remove the window from tracking
        if let workspaceId = windowOwnership[windowId],
           let workspace = workspaces.first(where: { $0.id == workspaceId }),
           let windowNode = workspace.findWindowNode(systemWindowID: windowId) {
            
            // Remove from parent
            if let parent = windowNode.parent {
                var mutableParent = parent
                mutableParent.remove(windowNode)
            }
            
            // Remove from ownership map
            windowOwnership.removeValue(forKey: windowId)
            
            // Apply tiling to reposition remaining windows
            if TilingEngine.shared.currentMode != .float {
                debounceApplyTiling()
            }
        }
    }
    
    // MARK: - Tiling Operations
    
    /// Apply current tiling mode to the active workspace
    func applyCurrentTiling() {
        guard let workspace = selectedWorkspace,
              let monitor = monitors.first(where: { $0.workspaces.contains(where: { $0.id == workspace.id }) }) else {
            return
        }
        
        // Apply tiling using the TilingEngine
        TilingEngine.shared.applyTiling(to: workspace, on: monitor)
    }
    
    /// Apply current tiling with pinning
    func applyCurrentTilingWithPinning() {
        guard let workspace = selectedWorkspace,
              let monitor = monitors.first(where: { $0.workspaces.contains(where: { $0.id == workspace.id }) }) else {
            return
        }
        
        // Apply tiling using the TilingEngine
        TilingEngine.shared.applyTilingAndPin(to: workspace, on: monitor)
    }
    
    /// Cycle to the next tiling mode and apply it
    func cycleAndApplyNextTilingMode() {
        // Cycle to next mode
        let newMode = TilingEngine.shared.cycleToNextMode()
        
        // Apply the new tiling mode
        applyCurrentTiling()
        
        // Update pinning state based on new mode
        handleTilingModeChange()
        
        print("Switched to \(newMode.description) mode")
    }
    
    /// Handle tiling mode change with pinning update
    func handleTilingModeChange() {
        // If switching to float, disable pinning
        if TilingEngine.shared.currentMode == .float {
            disableWindowPinning()
        } else {
            // For BSP and Stack modes, apply tiling and enable pinning
            applyCurrentTilingWithPinning()
        }
    }
    
    /// Apply tiling with debouncing to avoid excessive operations
    private func debounceApplyTiling() {
        // Use a static work item that's shared across the app
        DispatchQueue.tilingWorkItem?.cancel()
        
        // Create new work item
        let workItem = DispatchWorkItem { [weak self] in
            self?.applyCurrentTiling()
        }
        
        // Store for later cancellation
        DispatchQueue.tilingWorkItem = workItem
        
        // Schedule after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    // MARK: - Window Pinning
    
    /// Enable window pinning to prevent manual movement
    func enableWindowPinning() {
        // Store original position of all windows
        storeAllWindowPositions()
        
        // Start listening for window moves
        startListeningForWindowMoves()
    }
    
    /// Disable window pinning
    func disableWindowPinning() {
        windowPinningEnabled = false
        stopPinningTimer()
    }
    
    /// Store the positions of all windows
    private func storeAllWindowPositions() {
        windowPinningEnabled = true
        pinnedWindowPositions.removeAll()
        
        // Store positions of all windows
        for workspace in workspaces {
            for windowNode in workspace.root.getAllWindowNodes() {
                if let windowId = windowNode.systemWindowID,
                   let frame = windowNode.frame {
                    pinnedWindowPositions[windowId] = frame
                }
            }
        }
    }
    
    /// Start listening for window move events
    private func startListeningForWindowMoves() {
        // Already set up in WindowObserver, just need to process the events properly
        
        // But we'll also set up a backup timer to restore positions periodically
        stopPinningTimer()
        
        pinningTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkAndRestoreWindowPositions()
        }
    }
    
    /// Stop the pinning timer
    private func stopPinningTimer() {
        pinningTimer?.invalidate()
        pinningTimer = nil
    }
    
    /// Check and restore window positions if they've been moved
    private func checkAndRestoreWindowPositions() {
        guard windowPinningEnabled else { return }
        
        for (windowId, pinnedFrame) in pinnedWindowPositions {
            if let windowElement = AccessibilityService.shared.getWindowElement(for: CGWindowID(windowId)),
               let currentPosition = AccessibilityService.shared.getPosition(for: windowElement),
               let currentSize = AccessibilityService.shared.getSize(for: windowElement) {
                
                let currentFrame = NSRect(origin: currentPosition, size: currentSize)
                
                // If position has changed by more than a small threshold, restore it
                let positionThreshold: CGFloat = 5.0
                if abs(currentFrame.origin.x - pinnedFrame.origin.x) > positionThreshold ||
                   abs(currentFrame.origin.y - pinnedFrame.origin.y) > positionThreshold {
                    
                    // Restore the pinned position
                    AccessibilityService.shared.setPosition(pinnedFrame.origin, for: windowElement)
                }
                
                // If size has changed by more than a small threshold, restore it
                let sizeThreshold: CGFloat = 5.0
                if abs(currentFrame.size.width - pinnedFrame.size.width) > sizeThreshold ||
                   abs(currentFrame.size.height - pinnedFrame.size.height) > sizeThreshold {
                    
                    // Restore the pinned size
                    AccessibilityService.shared.setSize(pinnedFrame.size, for: windowElement)
                }
            }
        }
    }
    
    /// Update the pinned position for a specific window
    func updatePinnedPosition(for windowId: Int, frame: NSRect) {
        pinnedWindowPositions[windowId] = frame
    }
    
    /// Handle window moved event specifically for pinning
    func handleWindowMovedForPinning(windowId: Int) {
        guard windowPinningEnabled, let pinnedFrame = pinnedWindowPositions[windowId] else { return }
        
        if let windowElement = AccessibilityService.shared.getWindowElement(for: CGWindowID(windowId)) {
            // Restore the pinned position
            AccessibilityService.shared.setPosition(pinnedFrame.origin, for: windowElement)
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
        print("Window Pinning Enabled: \(windowPinningEnabled)")
        print("Pinned Windows Count: \(pinnedWindowPositions.count)")
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

// MARK: - Singleton Provider

/// Utility class to provide a singleton instance of the window manager
    /// Shared window manager instance
