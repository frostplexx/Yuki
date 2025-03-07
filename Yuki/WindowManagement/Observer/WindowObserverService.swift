//
//  WindowObserverService.swift
//  Yuki
//
//  Created by Daniel Inama on 7/3/25.
//

import Foundation
import Cocoa

/// Notification names for window events
extension Notification.Name {
    static let windowMoved = Notification.Name("com.yuki.WindowMoved")
    static let windowResized = Notification.Name("com.yuki.WindowResized")
    static let windowCreated = Notification.Name("com.yuki.WindowCreated")
    static let windowRemoved = Notification.Name("com.yuki.WindowRemoved")
    static let windowMinimized = Notification.Name("com.yuki.WindowMinimized")
    static let windowUnminimized = Notification.Name("com.yuki.WindowUnminimized")
    static let windowClosed = Notification.Name("com.yuki.WindowClosed")
    static let workspaceActivated = Notification.Name("com.yuki.WorkspaceActivated")
    static let tilingModeChanged = Notification.Name("com.yuki.TilingModeChanged")
}

/// Central service for all window and application observation
class WindowObserverService {
    // MARK: - Singleton
    
    /// Shared instance
    static let shared = WindowObserverService()
    
    // MARK: - Properties
    
    /// Internal notification center
    private let notificationCenter = NotificationCenter.default
    
    /// Keep track of apps we're observing for window creation
    private var observedApps: [pid_t: AXObserver] = [:]
    
    /// Previously observed window positions
    private var previousWindowPositions: [Int: NSRect] = [:]
    
    /// Timer for periodic window position checks
    private var observationTimer: Timer?
    
    /// Observation interval (in seconds)
    private let observationInterval: TimeInterval = 0.1
    
    /// Lock screen app bundle identifier
    private let lockScreenAppBundleId = "com.apple.loginwindow"
    
    /// Flag to track if we're currently handling a window event to prevent cascading
    private var isHandlingWindowEvent = false
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton pattern
    }
    
    // MARK: - Starting/Stopping Observation
    
    /// Start observing all window and application events
    @MainActor
    func start() {
        // Initialize system notification observers
        registerForSystemNotifications()
        
        // Start window movement observation
        startWindowMoveObservation()
        
        // Register for applications that are already running
        registerExistingApplications()
        
        print("WindowObserverService started successfully")
    }
    
    /// Stop all observation
    func stop() {
        // Remove all notification observers
        notificationCenter.removeObserver(self)
        
        // Stop window movement observation
        stopWindowMoveObservation()
        
        // Unregister from all app observations
        for (pid, _) in observedApps {
            unregisterFromWindowNotifications(for: pid)
        }
        
        print("WindowObserverService stopped")
    }
    
    // MARK: - System Notification Registration
    
    /// Register for system-level notifications
    @MainActor
    private func registerForSystemNotifications() {
        let nc = NSWorkspace.shared.notificationCenter
        
        // Application lifecycle events
        nc.addObserver(self, selector: #selector(handleAppLaunched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleAppActivated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleAppHidden(_:)), name: NSWorkspace.didHideApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleAppUnhidden(_:)), name: NSWorkspace.didUnhideApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleAppDeactivated(_:)), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleAppTerminated(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        
        // Space changes
        nc.addObserver(self, selector: #selector(handleSpaceChanged(_:)), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        
        // Window closing notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleWindowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)
    }
    
    /// Register for window creation notifications for existing applications
    private func registerExistingApplications() {
        for runningApp in NSWorkspace.shared.runningApplications {
            if runningApp.activationPolicy == .regular {
                registerForWindowCreationNotifications(for: runningApp.processIdentifier)
            }
        }
    }
    
    // MARK: - Window Movement Observation
    
    /// Start observing window movements
    private func startWindowMoveObservation() {
        stopWindowMoveObservation() // Stop any existing timer
        
        // Create initial window position cache
        updateWindowPositionCache()
        
        // Start timer to periodically check for window movements
        observationTimer = Timer.scheduledTimer(
            timeInterval: observationInterval,
            target: self,
            selector: #selector(checkForWindowMovements),
            userInfo: nil,
            repeats: true
        )
    }
    
    /// Stop observing window movements
    private func stopWindowMoveObservation() {
        observationTimer?.invalidate()
        observationTimer = nil
    }
    
    /// Update the cache of window positions
    private func updateWindowPositionCache() {
        // Get current window list
        let windows = WindowManager.shared.windowDiscovery.getAllVisibleWindows()
        
        for windowInfo in windows {
            guard let windowId = windowInfo["kCGWindowNumber"] as? Int,
                  let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat else {
                continue
            }
            
            // Store current position and size
            let frame = NSRect(x: x, y: y, width: width, height: height)
            previousWindowPositions[windowId] = frame
        }
    }
    
    // MARK: - AX Notification Registration
    
    /// Register for AX notifications when windows are created in an application
    private func registerForWindowCreationNotifications(for pid: pid_t) {
        // Skip if already observing
        if observedApps[pid] != nil {
            return
        }
        
        // Create AX observer
        var observer: AXObserver?
        let error = AXObserverCreate(pid, axNotificationCallback, &observer)
        
        guard error == .success, let observer = observer else {
            print("Failed to create AX observer for application with PID \(pid): \(error)")
            return
        }
        
        // Get the application element
        let appElement = AXUIElementCreateApplication(pid)
        
        // Register for window creation, focus, minimization and activation notifications
        AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, nil)
        AXObserverAddNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString, nil)
        AXObserverAddNotification(observer, appElement, kAXApplicationActivatedNotification as CFString, nil)
        AXObserverAddNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString, nil)
        AXObserverAddNotification(observer, appElement, kAXWindowDeminiaturizedNotification as CFString, nil)
        
        // Add to CFRunLoop to receive notifications
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        
        // Store the observer
        observedApps[pid] = observer
    }
    
    /// Unregister from AX notifications for an application
    private func unregisterFromWindowNotifications(for pid: pid_t) {
        guard let observer = observedApps[pid] else { return }
        
        // Remove observer from run loop and release
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        
        observedApps.removeValue(forKey: pid)
    }
    
    // MARK: - Event Handlers
    
    @objc private func handleAppLaunched(_ notification: Notification) {
        if (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == lockScreenAppBundleId {
            return
        }
        
        // For application launch, register for window creation notifications
        if let launchedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            registerForWindowCreationNotifications(for: launchedApp.processIdentifier)
        }
        
        // Only refresh the monitor with mouse
        refreshActiveMonitor()
    }
    
    @objc private func handleAppActivated(_ notification: Notification) {
        if (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == lockScreenAppBundleId {
            return
        }
        
        if let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            handleAppActivation(activatedApp)
        }
        
        // Only refresh the monitor with mouse
        refreshActiveMonitor()
    }
    
    @objc private func handleAppHidden(_ notification: Notification) {
        if let hiddenApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            WindowManager.shared.removeWindowsForApp(hiddenApp.processIdentifier)
        }
    }
    
    @objc private func handleAppUnhidden(_ notification: Notification) {
        // Only refresh the monitor with mouse
        refreshActiveMonitor()
    }
    
    @objc private func handleAppDeactivated(_ notification: Notification) {
        // Only refresh the monitor with mouse
        refreshActiveMonitor()
    }
    
    @objc private func handleAppTerminated(_ notification: Notification) {
        if let terminatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            let pid = terminatedApp.processIdentifier
            // Unregister from window notifications for this app
            unregisterFromWindowNotifications(for: pid)
            // Remove windows for this app
            WindowManager.shared.removeWindowsForApp(pid)
        }
    }
    
    @objc private func handleSpaceChanged(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshActiveMonitor()
        }
    }
    
    @objc private func handleWindowWillClose(_ notification: Notification) {
        // Get the window that's closing
        if let window = notification.object as? NSWindow {
            // Try to match it with our tracked windows
            let windowId = window.windowNumber
            
            // Post window closed notification
            postWindowRemoved(windowId)
            routeWindowEvent(.closed, windowId: windowId)
            
            // Only refresh the active monitor
            if let activeMonitor = WindowManager.shared.monitorWithMouse {
                refreshWindowsOnMonitor(activeMonitor)
            }
        }
    }
    
    /// Handle application activation (dock click, cmd+tab, etc.)
    private func handleAppActivation(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        
        // Try to find a workspace containing a window from this app
        let workspaces = findWorkspacesContainingApp(pid)
        if let targetWorkspace = workspaces.first {
            // Only switch workspaces if needed
            if targetWorkspace.monitor.activeWorkspace?.id != targetWorkspace.id {
                print("App activation detected (\(app.localizedName ?? "Unknown")), activating workspace: \(targetWorkspace.title ?? "Unknown")")
                DispatchQueue.main.async {
                    targetWorkspace.activate()
                }
            }
        }
    }
    
    // Find all workspaces that contain windows from the given application
    private func findWorkspacesContainingApp(_ pid: pid_t) -> [WorkspaceNode] {
        var result: [WorkspaceNode] = []
        
        for monitor in WindowManager.shared.monitors {
            for workspace in monitor.workspaces {
                // Check if this workspace has any windows from this application
                let windowNodes = workspace.getAllWindowNodes()
                let hasAppWindow = windowNodes.contains { node in
                    WindowManager.shared.getPID(for: node.window) == pid
                }
                
                if hasAppWindow {
                    result.append(workspace)
                }
            }
        }
        
        return result
    }
    
    // MARK: - Window Movement Detection
    
    /// Check for window movements by comparing current positions to previous positions
    @objc private func checkForWindowMovements() {
        // Avoid processing if we're already handling a window event
        if isHandlingWindowEvent {
            return
        }
        
        isHandlingWindowEvent = true
        defer { isHandlingWindowEvent = false }
        
        // Get current window list
        let windows = WindowManager.shared.windowDiscovery.getAllVisibleWindows()
        
        for windowInfo in windows {
            guard let windowId = windowInfo["kCGWindowNumber"] as? Int,
                  let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat,
                  let previousFrame = previousWindowPositions[windowId] else {
                continue
            }
            
            // Current frame
            let currentFrame = NSRect(x: x, y: y, width: width, height: height)
            
            // Check if position changed
            let positionThreshold: CGFloat = 2.0 // Small threshold to avoid false positives
            let positionChanged = abs(currentFrame.origin.x - previousFrame.origin.x) > positionThreshold ||
                                 abs(currentFrame.origin.y - previousFrame.origin.y) > positionThreshold
            
            // Check if size changed
            let sizeThreshold: CGFloat = 2.0
            let sizeChanged = abs(currentFrame.size.width - previousFrame.size.width) > sizeThreshold ||
                             abs(currentFrame.size.height - previousFrame.size.height) > sizeThreshold
            
            // Check for minimized state
            // If window is minimized, height and width typically become very small
            let isMinimized = width < 10 || height < 10
            let wasMinimized = previousFrame.width < 10 || previousFrame.height < 10
            
            if isMinimized && !wasMinimized {
                // Window was minimized
                postWindowMinimized(windowId)
                routeWindowEvent(.minimized, windowId: windowId)
            } else if !isMinimized && wasMinimized {
                // Window was unminimized
                postWindowUnminimized(windowId)
                routeWindowEvent(.unminimized, windowId: windowId)
            }
            
            // Post appropriate notifications and directly notify the affected workspace
            if positionChanged {
                previousWindowPositions[windowId] = currentFrame
                postWindowMoved(windowId)
                routeWindowEvent(.moved, windowId: windowId)
            }
            
            if sizeChanged && !isMinimized && !wasMinimized {
                // Only report size changes for non-minimized windows
                previousWindowPositions[windowId] = currentFrame
                postWindowResized(windowId)
                routeWindowEvent(.resized, windowId: windowId)
            }
        }
        
        // Check for new windows
        let currentWindowIds = Set(windows.compactMap { $0["kCGWindowNumber"] as? Int })
        let previousWindowIds = Set(previousWindowPositions.keys)
        
        // New windows
        let newWindowIds = currentWindowIds.subtracting(previousWindowIds)
        for windowId in newWindowIds {
            if let windowInfo = windows.first(where: { ($0["kCGWindowNumber"] as? Int) == windowId }),
               let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
               let x = bounds["X"] as? CGFloat,
               let y = bounds["Y"] as? CGFloat,
               let width = bounds["Width"] as? CGFloat,
               let height = bounds["Height"] as? CGFloat {
                
                previousWindowPositions[windowId] = NSRect(x: x, y: y, width: width, height: height)
                postWindowCreated(windowId)
                routeWindowEvent(.created, windowId: windowId)
            }
        }
        
        // Removed windows
        let removedWindowIds = previousWindowIds.subtracting(currentWindowIds)
        for windowId in removedWindowIds {
            previousWindowPositions.removeValue(forKey: windowId)
            postWindowRemoved(windowId)
            routeWindowEvent(.removed, windowId: windowId)
        }
    }
    
    // MARK: - Targeted Refreshing
    
    /// Refresh only the active monitor (the one with the mouse)
    private func refreshActiveMonitor() {
        guard let activeMonitor = WindowManager.shared.monitorWithMouse else {
            // If for some reason we can't determine the active monitor, fall back to refreshing all
            WindowManager.shared.refreshWindowsList()
            return
        }
        
        // Get windows on this monitor
        refreshWindowsOnMonitor(activeMonitor)
    }
    
    /// Refresh windows for a specific monitor
    func refreshWindowsOnMonitor(_ monitor: Monitor) {
        DispatchQueue.main.async {
            // Get all visible windows
            let visibleWindows = WindowManager.shared.windowDiscovery.getAllVisibleWindows()
            let visibleWindowIds = Set(visibleWindows.compactMap { $0["kCGWindowNumber"] as? Int })
            
            // Process each workspace on this monitor
            for var workspace in monitor.workspaces {
                // Get all window nodes in the workspace
                let windowNodes = workspace.getAllWindowNodes()
                
                // Remove windows that are no longer visible
                for windowNode in windowNodes {
                    // Convert the windowNode's system ID to an integer for comparison
                    if let systemWindowId = windowNode.systemWindowID,
                       let windowId = Int(systemWindowId),
                       !visibleWindowIds.contains(windowId) {
                        
                        // Remove from ownership tracking
                        WindowManager.shared.windowOwnership.removeValue(forKey: windowId)
                        
                        // Remove from workspace
                        workspace.remove(windowNode)
                        
                        print("Removed closed/hidden window \(windowId) from workspace \(workspace.title ?? "Unknown")")
                    }
                }
            }
            
            // Discover and assign any new windows on this monitor
            if let activeWorkspace = monitor.activeWorkspace {
                for windowInfo in visibleWindows {
                    guard let windowId = windowInfo["kCGWindowNumber"] as? Int,
                          let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
                          let x = bounds["X"] as? CGFloat,
                          let y = bounds["Y"] as? CGFloat else {
                        continue
                    }
                    
                    // Skip windows that are already assigned
                    if WindowManager.shared.windowOwnership[windowId] != nil {
                        continue
                    }
                    
                    // Check if window is on this monitor
                    let windowPosition = NSPoint(x: x, y: y)
                    if monitor.contains(point: windowPosition) {
                        // Try to get the window element
                        if let window = WindowManager.shared.windowDiscovery.getWindowElement(for: CGWindowID(windowId)) {
                            // Add window to active workspace
                            activeWorkspace.adoptWindow(window)
                            
                            // Register ownership
                            WindowManager.shared.windowOwnership[windowId] = activeWorkspace.id
                            
//                            print("Added new window \(windowId) to workspace \(activeWorkspace.title ?? "Unknown")")
                        }
                    }
                }
                
                // Apply tiling to update layout if needed
                if activeWorkspace.tilingEngine?.currentModeName != "float" {
                    activeWorkspace.applyTiling()
                }
            }
        }
    }
    
    // MARK: - Window Event Routing
    
    /// Event types for window events
    enum WindowEventType {
        case moved, resized, created, removed, minimized, unminimized, closed
    }
    
    /// Route a window event directly to the affected workspace
    func routeWindowEvent(_ eventType: WindowEventType, windowId: Int) {
        // Find the workspace that owns this window
        guard let workspaceId = WindowManager.shared.windowOwnership[windowId],
              let affectedMonitor = WindowManager.shared.monitors.first(where: { monitor in
                  monitor.workspaces.contains(where: { $0.id == workspaceId })
              }),
              let workspace = affectedMonitor.workspaces.first(where: { $0.id == workspaceId }) else {
            return
        }
        
        // Only process if this workspace is active (except for minimization events which we handle anyway)
        if !workspace.isActive && eventType != .minimized && eventType != .unminimized && eventType != .closed {
            return
        }
        
        // Apply the appropriate action for the active workspace
        DispatchQueue.main.async {
            switch eventType {
            case .moved, .resized:
                // If it's not a float workspace, reapply tiling
                if workspace.tilingEngine?.currentModeName != "float" {
                    workspace.reapplyTilingWithDelay()
                }
                
            case .created:
                // Apply tiling if it's not a float workspace
                if workspace.tilingEngine?.currentModeName != "float" {
                    workspace.reapplyTilingWithDelay()
                }
                
            case .removed, .closed:
                // Remove from tracked positions
                var positions = workspace.tiledWindowPositions
                positions.removeValue(forKey: windowId)
                workspace.tiledWindowPositions = positions
                
                // Remove from window ownership map
                WindowManager.shared.windowOwnership.removeValue(forKey: windowId)
                
                // Remove the window from workspace
                if let windowElement = WindowManager.shared.windowDiscovery.getWindowElement(for: CGWindowID(windowId)),
                   let windowNode = workspace.findWindowNodeByAXUIElement(windowElement) {
                    var mutableWorkspace = workspace
                    mutableWorkspace.remove(windowNode)
                    print("Removed window \(windowId) from workspace \(workspace.title ?? "Unknown") due to \(eventType)")
                }
                
                // Reapply tiling to adjust remaining windows
                if workspace.tilingEngine?.currentModeName != "float" {
                    workspace.reapplyTilingWithDelay()
                }
                
            case .minimized:
                // For minimized windows, we don't reapply tiling immediately
                // but we update the tracked window state
                if let window = WindowManager.shared.windowDiscovery.getWindowElement(for: CGWindowID(windowId)),
                   let windowNode = workspace.findWindowNodeByAXUIElement(window) {
                    windowNode.isMinimized = true
                    print("Window \(windowId) marked as minimized in workspace \(workspace.title ?? "Unknown")")
                    
                    // If not float mode, reapply tiling to adjust layout for remaining windows
                    if workspace.tilingEngine?.currentModeName != "float" {
                        workspace.reapplyTilingWithDelay()
                    }
                }
                
            case .unminimized:
                // When a window is unminimized, it should return to the tiling layout
                if let window = WindowManager.shared.windowDiscovery.getWindowElement(for: CGWindowID(windowId)),
                   let windowNode = workspace.findWindowNodeByAXUIElement(window) {
                    windowNode.isMinimized = false
                    print("Window \(windowId) marked as unminimized in workspace \(workspace.title ?? "Unknown")")
                    
                    // Always reapply tiling to incorporate the unminimized window
                    if workspace.tilingEngine?.currentModeName != "float" {
                        workspace.reapplyTilingWithDelay()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get the active workspace that contains a window from the given app
    func getActiveWorkspaceForApp(_ pid: pid_t) -> WorkspaceNode? {
        // First check currently active workspaces
        for monitor in WindowManager.shared.monitors {
            if let workspace = monitor.activeWorkspace {
                let windowNodes = workspace.getAllWindowNodes()
                let hasAppWindow = windowNodes.contains { node in
                    WindowManager.shared.getPID(for: node.window) == pid
                }
                
                if hasAppWindow {
                    return workspace
                }
            }
        }
        
        // If not found in active workspaces, look in all workspaces
        let workspaces = findWorkspacesContainingApp(pid)
        return workspaces.first
    }
    
    // MARK: - Notification Posting
    
    /// Post a window moved notification
    func postWindowMoved(_ windowId: Int) {
        notificationCenter.post(name: .windowMoved, object: nil, userInfo: ["windowId": windowId])
//        print("Window \(windowId) moved")
    }
    
    /// Post a window resized notification
    func postWindowResized(_ windowId: Int) {
        notificationCenter.post(name: .windowResized, object: nil, userInfo: ["windowId": windowId])
//        print("Window \(windowId) resized")
    }
    
    /// Post a window created notification
    func postWindowCreated(_ windowId: Int) {
        notificationCenter.post(name: .windowCreated, object: nil, userInfo: ["windowId": windowId])
//        print("Window \(windowId) created")
    }
    
    /// Post a window removed notification
    func postWindowRemoved(_ windowId: Int) {
        notificationCenter.post(name: .windowRemoved, object: nil, userInfo: ["windowId": windowId])
//        print("Window \(windowId) removed")
    }
    
    /// Post a window closed notification
    func postWindowClosed(_ windowId: Int) {
        notificationCenter.post(name: .windowClosed, object: nil, userInfo: ["windowId": windowId])
//        print("Window \(windowId) closed with Cmd+W")
    }
    
    /// Post a window minimized notification
    func postWindowMinimized(_ windowId: Int) {
        notificationCenter.post(name: .windowMinimized, object: nil, userInfo: ["windowId": windowId])
//        print("Window \(windowId) minimized")
    }
    
    /// Post a window unminimized notification
    func postWindowUnminimized(_ windowId: Int) {
        notificationCenter.post(name: .windowUnminimized, object: nil, userInfo: ["windowId": windowId])
//        print("Window \(windowId) unminimized")
    }
    
    /// Post a workspace activated notification
    func postWorkspaceActivated(_ workspace: WorkspaceNode) {
        notificationCenter.post(name: .workspaceActivated, object: workspace)
//        print("Workspace \(workspace.title ?? "unknown") activated")
    }
    
    /// Post a tiling mode changed notification
    func postTilingModeChanged(_ workspace: WorkspaceNode) {
        notificationCenter.post(name: .tilingModeChanged, object: workspace)
//        print("Tiling mode changed for workspace \(workspace.title ?? "unknown")")
    }
}

// MARK: - AX Notification Callback

private let axNotificationCallback: AXObserverCallback = { observer, element, notification, userData in
    DispatchQueue.main.async {
        let notificationStr = notification as String
        
        // Handle different types of notifications
        switch notificationStr {
        case kAXWindowCreatedNotification:
            // Handle window creation
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            
            // Get windows for this app
            let windows = WindowManager.shared.windowDiscovery.getWindowsForApplication(pid: pid)
            for window in windows {
                var windowId: CGWindowID = 0
                if _AXUIElementGetWindow(window, &windowId) == .success,
                   let intId = Int(exactly: windowId),
                   WindowManager.shared.windowOwnership[intId] == nil {
                    // This is a new window, try to assign it to the active workspace
                    if let activeWorkspace = WindowObserverService.shared.getActiveWorkspaceForApp(pid) {
                        activeWorkspace.adoptWindow(window)
                        
                        // Post window created notification
                        WindowObserverService.shared.postWindowCreated(intId)
                    }
                }
            }
            
            // Only refresh the active monitor
            if let activeMonitor = WindowManager.shared.monitorWithMouse {
                WindowObserverService.shared.refreshWindowsOnMonitor(activeMonitor)
            }
            
        case kAXWindowMiniaturizedNotification:
            // Handle window minimization
            var windowId: CGWindowID = 0
            if _AXUIElementGetWindow(element, &windowId) == .success,
               let intId = Int(exactly: windowId) {
                // Post window minimized notification
                WindowObserverService.shared.postWindowMinimized(intId)
                WindowObserverService.shared.routeWindowEvent(.minimized, windowId: intId)
            }
            
        case kAXWindowDeminiaturizedNotification:
            // Handle window unmininimization
            var windowId: CGWindowID = 0
            if _AXUIElementGetWindow(element, &windowId) == .success,
               let intId = Int(exactly: windowId) {
                // Post window unminimized notification
                WindowObserverService.shared.postWindowUnminimized(intId)
                WindowObserverService.shared.routeWindowEvent(.unminimized, windowId: intId)
                
                // Refresh the active monitor since layout may need to be updated
                if let activeMonitor = WindowManager.shared.monitorWithMouse {
                    WindowObserverService.shared.refreshWindowsOnMonitor(activeMonitor)
                }
            }
            
        case kAXFocusedWindowChangedNotification, kAXApplicationActivatedNotification:
            // Only refresh the active monitor
            if let activeMonitor = WindowManager.shared.monitorWithMouse {
                WindowObserverService.shared.refreshWindowsOnMonitor(activeMonitor)
            }
            
        default:
            break
        }
    }
}

