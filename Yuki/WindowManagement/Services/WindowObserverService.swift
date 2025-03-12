// WindowObserverService.swift
// High-performance window event observation service

import Cocoa
import Foundation

// MARK: - Window Event Notifications

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

/// High-performance service for observing window and application events
class WindowObserverService {
    // MARK: - Singleton
    
    /// Shared instance
    static let shared = WindowObserverService()
    
    // MARK: - Properties
    
    /// Central notification center
    private let notificationCenter = NotificationCenter.default
    
    /// Observed applications for window events
    private var observedApps: [pid_t: AXObserver] = [:]
    
    /// Previous window positions for tracking movements
    private var previousWindowPositions: [CGWindowID: NSRect] = [:]
    
    /// Cache of window observation status to avoid redundant observations
    private var windowObservationCache: Set<CGWindowID> = []
    
    /// Timer for periodic window position checks
    private var observationTimer: Timer?
    
    /// Observation interval (in seconds) - reduced for faster response
    private let observationInterval: TimeInterval = 0.5
    
    /// Lock screen app bundle identifier (to ignore)
    private let lockScreenAppBundleId = "com.apple.loginwindow"
    
    /// Flag to prevent recursive event handling
    private var isHandlingWindowEvent = false
    
    /// High-priority queue for window management operations
    private let windowQueue = DispatchQueue(label: "com.yuki.windowQueue", qos: .userInteractive)
    
    /// Performance measuring for debugging
    private var lastRefreshTime: CFAbsoluteTime = 0
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton
    }
    
    // MARK: - Service Control
    
    /// Start observing system window events
    @MainActor
    func start() {
        // Set up system notification observers
        registerForSystemNotifications()
        
        // Start window movement observation
        startWindowMoveObservation()
        
        // Register for existing applications
        registerExistingApplications()
        
        print("WindowObserverService started")
    }
    
    /// Stop all observation
    func stop() {
        // Remove notification observers
        notificationCenter.removeObserver(self)
        
        // Stop window movement observation
        stopWindowMoveObservation()
        
        // Unregister from app observations
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
        nc.addObserver(self, selector: #selector(handleAppLaunched(_:)),
                      name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        
        nc.addObserver(self, selector: #selector(handleAppActivated(_:)),
                      name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        nc.addObserver(self, selector: #selector(handleAppTerminated(_:)),
                      name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        
        nc.addObserver(self, selector: #selector(handleAppHidden(_:)),
                      name: NSWorkspace.didHideApplicationNotification, object: nil)
        
        nc.addObserver(self, selector: #selector(handleAppUnhidden(_:)),
                      name: NSWorkspace.didUnhideApplicationNotification, object: nil)
        
        // Space changes
        nc.addObserver(self, selector: #selector(handleSpaceChanged(_:)),
                      name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        
        // Window closing notifications - register for all windows including future ones
        nc.addObserver(
            self,
            selector: #selector(handleWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        
        // Also register for window did become key to catch focus changes quickly
        nc.addObserver(
            self,
            selector: #selector(handleWindowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        
        // Register for window did become main for quicker response to new windows
        nc.addObserver(
            self,
            selector: #selector(handleWindowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
    }
    
    /// Register for window notifications from existing applications
    private func registerExistingApplications() {
        windowQueue.async {
            // Get all running applications in parallel
            let runningApps = NSWorkspace.shared.runningApplications
            
            // Filter just the regular apps (not background or UI Element apps)
            let regularApps = runningApps.filter { $0.activationPolicy == .regular }
            
            // Use concurrentPerform for parallel processing
            DispatchQueue.concurrentPerform(iterations: regularApps.count) { index in
                let app = regularApps[index]
                self.registerForWindowNotifications(for: app.processIdentifier)
            }
        }
    }
    
    // MARK: - Window Movement Observation
    
    /// Start observing window movements
    private func startWindowMoveObservation() {
        stopWindowMoveObservation()  // Stop any existing timer
        
        // Create initial window position cache
        updateWindowPositionCache()
        
        // Start timer for window movements with reduced interval for faster response
        observationTimer = Timer.scheduledTimer(
            timeInterval: observationInterval,
            target: self,
            selector: #selector(checkForWindowMovements),
            userInfo: nil,
            repeats: true
        )
        
        // Add to common run loop modes to ensure it runs during UI operations
        RunLoop.current.add(observationTimer!, forMode: .common)
    }
    
    /// Stop window movement observation
    private func stopWindowMoveObservation() {
        observationTimer?.invalidate()
        observationTimer = nil
    }
    
    /// Update cached window positions efficiently
    private func updateWindowPositionCache() {
        // Get current windows
        let windows = WindowManager.shared.windowDiscovery.getAllVisibleWindows()
        
        windowQueue.async(flags: .barrier) {
            for windowInfo in windows {
                guard let windowIdInt = windowInfo["kCGWindowNumber"] as? Int,
                      let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
                      let x = bounds["X"] as? CGFloat,
                      let y = bounds["Y"] as? CGFloat,
                      let width = bounds["Width"] as? CGFloat,
                      let height = bounds["Height"] as? CGFloat
                else { continue }
                
                let windowId = CGWindowID(windowIdInt)
                let frame = NSRect(x: x, y: y, width: width, height: height)
                self.previousWindowPositions[windowId] = frame
            }
        }
    }
    
    // MARK: - AX Notification Registration
    
    /// Register for window creation notifications for an application
    private func registerForWindowNotifications(for pid: pid_t) {
        // Skip if already observing
        if observedApps[pid] != nil {
            return
        }
        
        // Create AX observer (with high-priority queue)
        var observer: AXObserver?
        let error = AXObserverCreate(pid, axNotificationCallback, &observer)
        
        guard error == .success, let observer = observer else {
            if error != .cannotComplete {  // Ignore normal failures for apps we can't observe
                print("Failed to create AX observer for PID \(pid): \(error)")
            }
            return
        }
        
        // Get application element
        let appElement = AXUIElementCreateApplication(pid)
        
        // Register for notifications - using direct CFStringRefs for performance
        AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, nil)
        AXObserverAddNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString, nil)
        AXObserverAddNotification(observer, appElement, kAXApplicationActivatedNotification as CFString, nil)
        AXObserverAddNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString, nil)
        AXObserverAddNotification(observer, appElement, kAXWindowDeminiaturizedNotification as CFString, nil)
        
        // Add to run loop with immediate dispatch to ensure callbacks happen quickly
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
        
        // Store the observer
        windowQueue.async(flags: .barrier) {
            self.observedApps[pid] = observer
        }
    }
    
    /// Unregister from AX notifications for an application
    private func unregisterFromWindowNotifications(for pid: pid_t) {
        guard let observer = observedApps[pid] else { return }
        
        // Remove observer from run loop
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
        
        windowQueue.async(flags: .barrier) {
            self.observedApps.removeValue(forKey: pid)
        }
    }
    
    // MARK: - Event Handlers
    
    @objc private func handleAppLaunched(_ notification: Notification) {
        guard let launchedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        // Skip system apps we want to ignore
        if launchedApp.bundleIdentifier == lockScreenAppBundleId {
            return
        }
        
        // Register for window notifications immediately
        windowQueue.async {
            self.registerForWindowNotifications(for: launchedApp.processIdentifier)
            
            // Immediate refresh to discover new windows
            DispatchQueue.main.async {
                self.quickRefreshActiveMonitor()
            }
        }
    }
    
    @objc private func handleAppActivated(_ notification: Notification) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        // Skip system apps we want to ignore
        if activatedApp.bundleIdentifier == lockScreenAppBundleId {
            return
        }
        
        windowQueue.async {
            self.handleAppActivation(activatedApp)
            
            // Immediately refresh windows for faster response
            DispatchQueue.main.async {
                self.quickRefreshActiveMonitor()
            }
        }
    }
    
    @objc private func handleAppHidden(_ notification: Notification) {
        guard let hiddenApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        windowQueue.async {
            WindowManager.shared.removeWindowsForApp(hiddenApp.processIdentifier)
        }
    }
    
    @objc private func handleAppUnhidden(_ notification: Notification) {
        // Quick refresh for faster response
        quickRefreshActiveMonitor()
    }
    
    @objc private func handleAppTerminated(_ notification: Notification) {
        guard let terminatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let pid = terminatedApp.processIdentifier
        
        windowQueue.async {
            // Unregister from window notifications
            self.unregisterFromWindowNotifications(for: pid)
            
            // Remove all windows for this app immediately
            WindowManager.shared.removeWindowsForApp(pid)
            
            // Apply tiling to reflect changes
            if let activeMonitor = WindowManager.shared.monitorWithMouse,
               let activeWorkspace = activeMonitor.activeWorkspace {
                DispatchQueue.main.async {
                    activeWorkspace.applyTiling() // Direct apply for immediate feedback
                }
            }
        }
    }
    
    @objc private func handleSpaceChanged(_ notification: Notification) {
        // Immediate refresh for space changes with minimal delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.quickRefreshActiveMonitor()
        }
    }
    
    /// React immediately to window closing
    @objc private func handleWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        let windowId = CGWindowID(window.windowNumber)
        
        // CRITICAL: Do the first part directly on the main thread for maximum speed
        // Find workspace and window directly - synchronously
        if let windowNode = WindowManager.shared.findWindowNode(byID: windowId),
           let workspaceId = WindowManager.shared.windowOwnership[windowId],
           let workspace = WindowManager.shared.findWorkspace(byID: workspaceId) {
            
            // Remove window directly on main thread
            workspace.removeChild(windowNode)
            WindowManager.shared.unregisterWindowOwnership(windowID: windowId)
            
            // IMMEDIATE tiling update with no delay
            if workspace.isActive && workspace.tilingEngine.currentLayoutType != .float {
                // Direct synchronous call for immediate visual feedback
                workspace.applyTiling()
            }
            
            // Post notifications after we've already updated the UI
            self.postWindowClosed(windowId)
            self.postWindowRemoved(windowId)
        }
        
        // Clean up tracking asynchronously (less time-critical)
        windowQueue.async {
            self.previousWindowPositions.removeValue(forKey: windowId)
            self.windowObservationCache.remove(windowId)
        }
    }
    
    /// Quick response to window focus changes
    @objc private func handleWindowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Immediately update focused window state
        let windowId = CGWindowID(window.windowNumber)
        
        // Check if we're already tracking this window
        if WindowManager.shared.windowOwnership[windowId] == nil {
            // New window becoming key - try to adopt it
            windowQueue.async {
                if let elementWindow = WindowManager.shared.windowDiscovery.getWindowElement(for: windowId) {
                    if let activeMonitor = WindowManager.shared.monitorWithMouse,
                       let activeWorkspace = activeMonitor.activeWorkspace {
                        
                        DispatchQueue.main.async {
                            activeWorkspace.adoptWindow(elementWindow)
                            
                            // Apply tiling immediately for better feedback
                            if activeWorkspace.tilingEngine.currentLayoutType != .float {
                                activeWorkspace.applyTiling()
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Quick response to window becoming main
    @objc private func handleWindowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Similar to becoming key, but more specifically for main window
        let windowId = CGWindowID(window.windowNumber)
        
        // Only process if we're not already tracking this window
        if WindowManager.shared.windowOwnership[windowId] == nil {
            windowQueue.async {
                if let elementWindow = WindowManager.shared.windowDiscovery.getWindowElement(for: windowId) {
                    if let activeMonitor = WindowManager.shared.monitorWithMouse,
                       let activeWorkspace = activeMonitor.activeWorkspace {
                        
                        DispatchQueue.main.async {
                            activeWorkspace.adoptWindow(elementWindow)
                            
                            // Apply tiling immediately
                            if activeWorkspace.tilingEngine.currentLayoutType != .float {
                                activeWorkspace.applyTiling()
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Handle application activation with workspace switching
    private func handleAppActivation(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        
        // Look for a workspace containing a window from this app
        if let targetWorkspace = findWorkspaceContainingApp(pid) {
            // Only switch workspaces if needed
            if targetWorkspace.monitor.activeWorkspace?.id != targetWorkspace.id {
                DispatchQueue.main.async {
                    targetWorkspace.activate()
                }
            }
        }
    }
    
    /// Find workspace containing windows from a specific app (optimized)
    private func findWorkspaceContainingApp(_ pid: pid_t) -> WorkspaceNode? {
        // Get all monitors and workspaces once to avoid repeated access
        let allMonitors = WindowManager.shared.monitors
        
        // Use a flatter, more efficient search approach
        for monitor in allMonitors {
            for workspace in monitor.workspaces {
                // Direct check if any window belongs to this app
                let windowNodes = workspace.getAllWindowNodes()
                let hasAppWindow = windowNodes.contains { node in
                    var windowPid: pid_t = 0
                    AXUIElementGetPid(node.window, &windowPid)
                    return windowPid == pid
                }
                
                if hasAppWindow {
                    return workspace
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Window Movement Detection
    
    /// Check for window movements by comparing positions
    @objc private func checkForWindowMovements() {
        // Performance tracking
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Avoid recursive processing
        if isHandlingWindowEvent {
            return
        }
        
        isHandlingWindowEvent = true
        defer { isHandlingWindowEvent = false }
        
        // Get current windows with minimal allocations
        let windows = WindowManager.shared.windowDiscovery.getAllVisibleWindows()
        
        // Pre-compute window IDs for faster lookups
        let currentWindowIds = Set(windows.compactMap { $0["kCGWindowNumber"] as? Int }.map { CGWindowID($0) })
        
        // Use windowQueue with barrier for thread safety during updates
        windowQueue.async(flags: .barrier) {
            let previousWindowIds = Set(self.previousWindowPositions.keys)
            
            // Check existing windows for movement or resizing - most common case
            for windowInfo in windows {
                guard let windowIdInt = windowInfo["kCGWindowNumber"] as? Int,
                      let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
                      let x = bounds["X"] as? CGFloat,
                      let y = bounds["Y"] as? CGFloat,
                      let width = bounds["Width"] as? CGFloat,
                      let height = bounds["Height"] as? CGFloat else { continue }
                
                let windowId = CGWindowID(windowIdInt)
                let currentFrame = NSRect(x: x, y: y, width: width, height: height)
                
                // If we have previous position, check for changes
                if let previousFrame = self.previousWindowPositions[windowId] {
                    // Check for position change with minimal math
                    let positionThreshold: CGFloat = 2.0
                    let positionChanged = abs(currentFrame.origin.x - previousFrame.origin.x) > positionThreshold ||
                                        abs(currentFrame.origin.y - previousFrame.origin.y) > positionThreshold
                    
                    // Check for size change with minimal math
                    let sizeThreshold: CGFloat = 2.0
                    let sizeChanged = abs(currentFrame.size.width - previousFrame.size.width) > sizeThreshold ||
                                    abs(currentFrame.size.height - previousFrame.size.height) > sizeThreshold
                    
                    // Check for minimized state - quick check
                    let isMinimized = width < 10 || height < 10
                    let wasMinimized = previousFrame.width < 10 || previousFrame.height < 10
                    
                    // Handle minimization state changes
                    if isMinimized && !wasMinimized {
                        // Window was minimized
                        self.previousWindowPositions[windowId] = currentFrame
                        self.postWindowMinimized(windowId)
                        self.updateWindowMinimizedState(windowId, isMinimized: true)
                    } else if !isMinimized && wasMinimized {
                        // Window was unminimized
                        self.previousWindowPositions[windowId] = currentFrame
                        self.postWindowUnminimized(windowId)
                        self.updateWindowMinimizedState(windowId, isMinimized: false)
                    }
                    
                    // Handle movement and resize separately for efficiency
                    if positionChanged {
                        self.previousWindowPositions[windowId] = currentFrame
                        self.postWindowMoved(windowId)
                        self.queueTilingUpdate(for: windowId)
                    }
                    
                    if sizeChanged && !isMinimized && !wasMinimized {
                        self.previousWindowPositions[windowId] = currentFrame
                        self.postWindowResized(windowId)
                        self.queueTilingUpdate(for: windowId)
                    }
                } else {
                    // New window we haven't seen before
                    self.previousWindowPositions[windowId] = currentFrame
                    self.postWindowCreated(windowId)
                    
                    // Assign to workspace immediately
                    self.assignNewWindowToWorkspace(windowId, at: NSPoint(x: x, y: y))
                }
            }
            
            // Check for removed windows
            let removedWindowIds = previousWindowIds.subtracting(currentWindowIds)
            for windowId in removedWindowIds {
                self.previousWindowPositions.removeValue(forKey: windowId)
                self.postWindowRemoved(windowId)
                
                // Handle window removal immediately
                self.handleWindowRemoved(windowId)
            }
        }
        
        // Performance tracking - log if taking too long
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        if duration > 0.05 {  // Log only slow operations
            print("Window movement check took \(duration * 1000)ms")
        }
    }
    
    /// Direct update of window minimized state
    private func updateWindowMinimizedState(_ windowId: CGWindowID, isMinimized: Bool) {
        if let windowNode = WindowManager.shared.findWindowNode(byID: windowId) {
            // Update state immediately
            DispatchQueue.main.async {
                windowNode.isMinimized = isMinimized
                
                // Update workspace tiling
                if let workspaceId = WindowManager.shared.windowOwnership[windowId],
                   let workspace = WindowManager.shared.findWorkspace(byID: workspaceId),
                   workspace.isActive,
                   workspace.tilingEngine.currentLayoutType != .float {
                    workspace.applyTiling() // Direct apply for immediate feedback
                }
            }
        }
    }
    
    /// Immediate response to window removal (for detected removals)
    private func handleWindowRemoved(_ windowId: CGWindowID) {
        // CRITICAL: For optimal performance on the main detected closing path
        if Thread.isMainThread {
            // We're on main thread - do everything immediately
            if let workspaceId = WindowManager.shared.windowOwnership[windowId],
               let workspace = WindowManager.shared.findWorkspace(byID: workspaceId),
               let windowNode = WindowManager.shared.findWindowNode(byID: windowId) {
                
                // Direct synchronous operations for immediate visual feedback
                workspace.removeChild(windowNode)
                WindowManager.shared.unregisterWindowOwnership(windowID: windowId)
                
                // Immediately apply tiling with no delay
                if workspace.isActive && workspace.tilingEngine.currentLayoutType != .float {
                    workspace.applyTiling() // Direct synchronous apply for immediate feedback
                }
            }
        } else {
            // Secondary path - get to main thread as quickly as possible
            if let workspaceId = WindowManager.shared.windowOwnership[windowId],
               let workspace = WindowManager.shared.findWorkspace(byID: workspaceId),
               let windowNode = WindowManager.shared.findWindowNode(byID: windowId) {
                
                // Use a specific dispatch strategy to avoid priority inversion
                DispatchQueue.main.async(qos: .userInteractive) {
                    // Remove window
                    workspace.removeChild(windowNode)
                    WindowManager.shared.unregisterWindowOwnership(windowID: windowId)
                    
                    // Apply tiling immediately
                    if workspace.isActive && workspace.tilingEngine.currentLayoutType != .float {
                        workspace.applyTiling() // Direct apply for immediate feedback
                    }
                }
            }
        }
    }
    
    /// Queue tiling update for a window's workspace
    private func queueTilingUpdate(for windowId: CGWindowID) {
        if let workspaceId = WindowManager.shared.windowOwnership[windowId],
           let workspace = WindowManager.shared.findWorkspace(byID: workspaceId) {
            
            // Skip for inactive workspaces or float mode
            if !workspace.isActive || workspace.tilingEngine.currentLayoutType == .float {
                return
            }
            
            // Use smart delay strategy - shorter than before
            DispatchQueue.main.async {
                workspace.reapplyTilingWithDelay()
            }
        }
    }
    
    /// Quickly assign a new window to a workspace
    private func assignNewWindowToWorkspace(_ windowId: CGWindowID, at position: NSPoint) {
        // Skip if already assigned
        if WindowManager.shared.windowOwnership[windowId] != nil {
            return
        }
        
        // Find appropriate monitor and workspace
        windowQueue.async {
            if let targetMonitor = WindowManager.shared.monitorContaining(point: position),
               let targetWorkspace = targetMonitor.activeWorkspace,
               let window = WindowManager.shared.windowDiscovery.getWindowElement(for: windowId) {
                
                // Adopt window on main thread
                DispatchQueue.main.async {
                    targetWorkspace.adoptWindow(window)
                    
                    // Apply tiling immediately for faster response
                    if targetWorkspace.tilingEngine.currentLayoutType != .float {
                        targetWorkspace.applyTiling()
                    }
                }
            }
        }
    }
    
    // MARK: - Fast Refresh Methods
    
    /// High-performance refresh of just the active monitor
    func quickRefreshActiveMonitor() {
        // Performance tracking
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let activeMonitor = WindowManager.shared.monitorWithMouse else {
            WindowManager.shared.discoverAndAssignWindows()
            return
        }
        
        // Quick refresh of the active monitor
        refreshWindowsOnMonitor(activeMonitor, fast: true)
        
        // Performance monitoring
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        lastRefreshTime = duration
    }
    
    /// Optimized refresh of windows on a monitor
    func refreshWindowsOnMonitor(_ monitor: Monitor, fast: Bool = false) {
        // Get visible windows with minimal allocations
        let visibleWindows = WindowManager.shared.windowDiscovery.getAllVisibleWindows()
        let visibleWindowIds = Set(visibleWindows.compactMap { $0["kCGWindowNumber"] as? Int }.map { CGWindowID($0) })
        
        // Get active workspace for quicker access
        guard let activeWorkspace = monitor.activeWorkspace else { return }
        
        // Process using windowQueue for thread safety
        windowQueue.async {
            // Create a collection of windows to process - minimize locking time
            var nonOwnedWindowPositions: [(CGWindowID, NSPoint)] = []
            
            // First check all workspaces for windows that are no longer visible
            for workspace in monitor.workspaces {
                let windowNodes = workspace.getAllWindowNodes()
                
                // Find and remove disappeared windows
                let removedNodes = windowNodes.filter { node in
                    guard let windowId = node.systemWindowID else { return false }
                    return !visibleWindowIds.contains(windowId)
                }
                
                // Process removals if any found
                if !removedNodes.isEmpty {
                    DispatchQueue.main.async {
                        for node in removedNodes {
                            if let windowId = node.systemWindowID {
                                workspace.removeChild(node)
                                WindowManager.shared.unregisterWindowOwnership(windowID: windowId)
                            }
                        }
                    }
                }
            }
            
            // Find new windows that are not yet owned
            for windowInfo in visibleWindows {
                guard let windowId = windowInfo["kCGWindowNumber"] as? Int,
                      let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
                      let x = bounds["X"] as? CGFloat,
                      let y = bounds["Y"] as? CGFloat else {
                    continue
                }
                
                // Skip windows that are already assigned
                if WindowManager.shared.windowOwnership[CGWindowID(windowId)] != nil {
                    continue
                }
                
                // Check if window is on this monitor
                let windowPosition = NSPoint(x: x, y: y)
                if monitor.contains(point: windowPosition) {
                    nonOwnedWindowPositions.append((CGWindowID(windowId), windowPosition))
                }
            }
            
            // Process new windows in parallel if possible
            if !nonOwnedWindowPositions.isEmpty {
                let windowsToProcess = nonOwnedWindowPositions
                
                // Use concurrent processing for faster adoption
                DispatchQueue.concurrentPerform(iterations: windowsToProcess.count) { index in
                    let (windowId, _) = windowsToProcess[index]
                    if let window = WindowManager.shared.windowDiscovery.getWindowElement(for: windowId) {
                        DispatchQueue.main.async {
                            activeWorkspace.adoptWindow(window)
                        }
                    }
                }
                
                // Apply tiling with minimal delay for immediate feedback
                DispatchQueue.main.async {
                    if activeWorkspace.tilingEngine.currentLayoutType != .float {
                        activeWorkspace.applyTiling()
                    }
                }
            }
        }
    }
    
    // MARK: - Notification Posting (Optimized)
    
    /// Efficient notification posting methods
    func postWindowMoved(_ windowId: CGWindowID) {
        notificationCenter.post(name: .windowMoved, object: nil, userInfo: ["windowId": windowId])
    }
    
    func postWindowResized(_ windowId: CGWindowID) {
        notificationCenter.post(name: .windowResized, object: nil, userInfo: ["windowId": windowId])
    }
    
    func postWindowCreated(_ windowId: CGWindowID) {
        notificationCenter.post(name: .windowCreated, object: nil, userInfo: ["windowId": windowId])
    }
    
    func postWindowRemoved(_ windowId: CGWindowID) {
        notificationCenter.post(name: .windowRemoved, object: nil, userInfo: ["windowId": windowId])
    }
    
    func postWindowMinimized(_ windowId: CGWindowID) {
        notificationCenter.post(name: .windowMinimized, object: nil, userInfo: ["windowId": windowId])
    }
    
    func postWindowUnminimized(_ windowId: CGWindowID) {
        notificationCenter.post(name: .windowUnminimized, object: nil, userInfo: ["windowId": windowId])
    }
    
    func postWindowClosed(_ windowId: CGWindowID) {
        notificationCenter.post(name: .windowClosed, object: nil, userInfo: ["windowId": windowId])
    }
    
    func postWorkspaceActivated(_ workspace: WorkspaceNode) {
        notificationCenter.post(name: .workspaceActivated, object: workspace)
    }
    
    func postTilingModeChanged(_ workspace: WorkspaceNode) {
        notificationCenter.post(name: .tilingModeChanged, object: workspace)
    }
}

// MARK: - AX Notification Callback

/// High-performance callback for accessibility notifications
private let axNotificationCallback: AXObserverCallback = { observer, element, notification, userData in
    // Dispatch to main thread but with immediate execution flag for better responsiveness
    DispatchQueue.main.async(flags: .inheritQoS) {
        let notificationStr = notification as String
        
        switch notificationStr {
        case kAXWindowCreatedNotification:
            // Handle window creation immediately
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            
            // Get only the most recently created window to avoid unnecessary work
            let windows = WindowManager.shared.windowDiscovery.getWindowsForApplication(pid: pid)
            if let window = windows.last {
                var windowId: CGWindowID = 0
                if _AXUIElementGetWindow(window, &windowId) == .success {
                    if WindowManager.shared.windowOwnership[windowId] == nil {
                        // New window - assign to active workspace immediately
                        if let activeMonitor = WindowManager.shared.monitorWithMouse,
                           let activeWorkspace = activeMonitor.activeWorkspace {
                            
                            // Adopt window directly without delay
                            activeWorkspace.adoptWindow(window)
                            WindowObserverService.shared.postWindowCreated(windowId)
                            
                            // Apply tiling immediately for better feedback
                            if activeWorkspace.tilingEngine.currentLayoutType != .float {
                                activeWorkspace.applyTiling()
                            }
                        }
                    }
                }
            }
            
        case kAXWindowMiniaturizedNotification:
            // Handle minimization with direct access
            var windowId: CGWindowID = 0
            if _AXUIElementGetWindow(element, &windowId) == .success {
                WindowObserverService.shared.postWindowMinimized(windowId)
                
                // Update window state immediately
                if let windowNode = WindowManager.shared.findWindowNode(byID: windowId) {
                    windowNode.isMinimized = true
                    
                    // Update tiling immediately for affected workspace
                    if let workspaceId = WindowManager.shared.windowOwnership[windowId],
                       let workspace = WindowManager.shared.findWorkspace(byID: workspaceId),
                       workspace.isActive,
                       workspace.tilingEngine.currentLayoutType != .float {
                        workspace.applyTiling() // Direct apply for immediate feedback
                    }
                }
            }
            
        case kAXWindowDeminiaturizedNotification:
            // Handle unminimization with direct access
            var windowId: CGWindowID = 0
            if _AXUIElementGetWindow(element, &windowId) == .success {
                WindowObserverService.shared.postWindowUnminimized(windowId)
                
                // Update window state immediately
                if let windowNode = WindowManager.shared.findWindowNode(byID: windowId) {
                    windowNode.isMinimized = false
                    
                    // Update tiling immediately for affected workspace
                    if let workspaceId = WindowManager.shared.windowOwnership[windowId],
                       let workspace = WindowManager.shared.findWorkspace(byID: workspaceId),
                       workspace.isActive,
                       workspace.tilingEngine.currentLayoutType != .float {
                        workspace.applyTiling() // Direct apply for immediate feedback
                    }
                }
            }
            
        case kAXFocusedWindowChangedNotification, kAXApplicationActivatedNotification:
            // Process focus change immediately
            WindowObserverService.shared.quickRefreshActiveMonitor()
            
        default:
            break
        }
    }
}
