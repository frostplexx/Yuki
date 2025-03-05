//
//  WindowObserver.swift
//  Yuki
//
//  Created by Claude AI on 5/3/25.
//

import Cocoa
import ApplicationServices
import os

/// Types of window events that can be observed
enum WindowEventType: String {
    case created = "created"
    case closed = "closed"
    case moved = "moved"
    case resized = "resized"
    case titleChanged = "titleChanged"
    case minimized = "minimized"
    case unminimized = "unminimized"
    case focused = "focused"
    case appActivated = "appActivated"
    case appTerminated = "appTerminated"
    case spaceChanged = "spaceChanged"
}

/// Structure representing a window event
struct WindowEvent {
    let type: WindowEventType
    let windowId: CGWindowID?
    let pid: pid_t?
    let timestamp: Date
    let windowInfo: [String: Any]?
    
    init(type: WindowEventType, windowId: CGWindowID? = nil, pid: pid_t? = nil, windowInfo: [String: Any]? = nil) {
        self.type = type
        self.windowId = windowId
        self.pid = pid
        self.timestamp = Date()
        self.windowInfo = windowInfo
    }
}

/// Protocol for window event handlers
protocol WindowObserverDelegate: AnyObject {
    func handleWindowEvent(_ event: WindowEvent)
}

/// Class for observing window events efficiently
class WindowObserver {
    // MARK: - Properties
    
    /// Delegate to handle window events
    weak var delegate: WindowObserverDelegate?
    
    /// Logger for debugging and performance tracking
    private let logger = Logger(subsystem: "com.frostplexx.Yuki", category: "WindowObserver")
    
    /// Accessibility service reference
    private let accessibilityService = AccessibilityService.shared
    
    /// Dictionary mapping window IDs to their observation tokens
    private var observedWindows: [CGWindowID: ObservationToken] = [:]
    
    /// Dictionary mapping process IDs to their AXObservers
    private var observers: [pid_t: AXObserver] = [:]
    
    /// Structure to track observation tokens
    private struct ObservationToken {
        let element: AXUIElement
        let pid: pid_t
    }
    
    /// Notification center token for workspace notifications
    private var workspaceNotificationTokens: [NSObjectProtocol] = []
    
    /// Set of newly created window IDs to avoid duplicate events
    private var newlyCreatedWindows = Set<CGWindowID>()
    
    /// Last known window list for detecting new and closed windows
    private var lastKnownWindowIds = Set<CGWindowID>()
    
    // MARK: - Initialization and Cleanup
    
    init(delegate: WindowObserverDelegate) {
        self.delegate = delegate
        setupWorkspaceNotifications()
    }
    
    deinit {
        stopObserving()
    }
    
    // MARK: - Public Methods
    
    /// Start observing all windows
    func startObserving() {
        // Start with a clean slate
        stopObserving()
        
        // First fetch all current windows
        updateWindowList()
        
        // Schedule periodic window list refresh (at a reasonable interval)
        // This is a fallback to catch any windows we might miss with the event-based approach
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.updateWindowList()
        }
    }
    
    /// Stop observing all windows
    func stopObserving() {
        // Clean up window observation
        for (_, token) in observedWindows {
            if let observer = observers[token.pid] {
                accessibilityService.stopObserving(observer)
            }
        }
        
        // Clean up observers
        observers.removeAll()
        observedWindows.removeAll()
        
        // Remove workspace notification tokens
        for token in workspaceNotificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        workspaceNotificationTokens.removeAll()
    }
    
    /// Force refresh of the window list
    func refreshWindowList() {
        updateWindowList()
    }
    
    // MARK: - Private Methods
    
    /// Setup notifications from the workspace
    private func setupWorkspaceNotifications() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // Application activated
        let appActivatedToken = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationActivated(notification)
        }
        workspaceNotificationTokens.append(appActivatedToken)
        
        // Application terminated
        let appTerminatedToken = notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationTerminated(notification)
        }
        workspaceNotificationTokens.append(appTerminatedToken)
        
        // Space changed
        let spaceChangedToken = notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSpaceChanged(notification)
        }
        workspaceNotificationTokens.append(spaceChangedToken)
    }
    
    /// Update the list of windows and detect changes
    private func updateWindowList() {
        // Get current window list
        let currentWindows = accessibilityService.getAllVisibleWindows()
        
        // Create set of current window IDs
        let currentWindowIds = Set(currentWindows.compactMap { $0["kCGWindowNumber"] as? Int }.map { CGWindowID($0) })
        
        // Find new windows (current - last known)
        let newWindowIds = currentWindowIds.subtracting(lastKnownWindowIds).subtracting(newlyCreatedWindows)
        
        // Find closed windows (last known - current)
        let closedWindowIds = lastKnownWindowIds.subtracting(currentWindowIds)
        
        // Handle new windows
        for windowId in newWindowIds {
            if let windowInfo = currentWindows.first(where: { ($0["kCGWindowNumber"] as? Int) == Int(windowId) }) {
                handleNewWindow(windowId: windowId, windowInfo: windowInfo)
            }
        }
        
        // Handle closed windows
        for windowId in closedWindowIds {
            handleClosedWindow(windowId: windowId)
        }
        
        // Update last known window list
        lastKnownWindowIds = currentWindowIds
        
        // Clear newly created windows set (they're now in lastKnownWindowIds)
        newlyCreatedWindows.removeAll()
        
        // Schedule next update with a reasonable interval
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.updateWindowList()
        }
    }
    
    /// Handle a new window being detected
    private func handleNewWindow(windowId: CGWindowID, windowInfo: [String: Any]) {
        guard let pid = windowInfo["kCGWindowOwnerPID"] as? pid_t else { return }
        
        // Add to newly created windows set
        newlyCreatedWindows.insert(windowId)
        
        // Create window observation
        if let windowElement = accessibilityService.getWindowElement(for: windowId) {
            observeWindow(windowElement, windowId: windowId, pid: pid)
            
            // Notify delegate
            let event = WindowEvent(type: .created, windowId: windowId, pid: pid, windowInfo: windowInfo)
            delegate?.handleWindowEvent(event)
        }
    }
    
    /// Handle a window being closed
    private func handleClosedWindow(windowId: CGWindowID) {
        // Remove observation
        if let token = observedWindows[windowId] {
            if let observer = observers[token.pid] {
                // Remove notifications for this window
                accessibilityService.removeNotification(kAXMovedNotification, from: token.element, for: observer)
                accessibilityService.removeNotification(kAXResizedNotification, from: token.element, for: observer)
                accessibilityService.removeNotification(kAXTitleChangedNotification, from: token.element, for: observer)
                accessibilityService.removeNotification(kAXUIElementDestroyedNotification, from: token.element, for: observer)
            }
            
            // Remove from observed windows
            observedWindows.removeValue(forKey: windowId)
        }
        
        // Notify delegate
        let event = WindowEvent(type: .closed, windowId: windowId)
        delegate?.handleWindowEvent(event)
    }
    
    /// Observe a specific window for events
    private func observeWindow(_ window: AXUIElement, windowId: CGWindowID, pid: pid_t) {
        // Check if we're already observing this window
        if observedWindows[windowId] != nil {
            return
        }
        
        // Get or create observer for this process
        let observer: AXObserver
        if let existingObserver = observers[pid] {
            observer = existingObserver
        } else if let newObserver = accessibilityService.createObserver(for: pid, callback: windowEventCallback) {
            observer = newObserver
            observers[pid] = observer
            accessibilityService.startObserving(observer)
        } else {
            return
        }
        
        // Create context pointers for different notifications
        let movedContext = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<CGWindowID>.size, alignment: MemoryLayout<CGWindowID>.alignment)
        movedContext.storeBytes(of: windowId, as: CGWindowID.self)
        
        let resizedContext = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<CGWindowID>.size, alignment: MemoryLayout<CGWindowID>.alignment)
        resizedContext.storeBytes(of: windowId, as: CGWindowID.self)
        
        let titleContext = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<CGWindowID>.size, alignment: MemoryLayout<CGWindowID>.alignment)
        titleContext.storeBytes(of: windowId, as: CGWindowID.self)
        
        let destroyedContext = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<CGWindowID>.size, alignment: MemoryLayout<CGWindowID>.alignment)
        destroyedContext.storeBytes(of: windowId, as: CGWindowID.self)
        
        // Add notifications to observer
        accessibilityService.addNotification(kAXMovedNotification, to: window, for: observer, userData: movedContext)
        accessibilityService.addNotification(kAXResizedNotification, to: window, for: observer, userData: resizedContext)
        accessibilityService.addNotification(kAXTitleChangedNotification, to: window, for: observer, userData: titleContext)
        accessibilityService.addNotification(kAXUIElementDestroyedNotification, to: window, for: observer, userData: destroyedContext)
        
        // Store token
        observedWindows[windowId] = ObservationToken(element: window, pid: pid)
    }
    
    // MARK: - Workspace Notification Handlers
    
    /// Handle application activated notification
    private func handleApplicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        // Notify delegate
        let event = WindowEvent(type: .appActivated, pid: app.processIdentifier)
        delegate?.handleWindowEvent(event)
        
        // Update window list to catch new windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateWindowList()
        }
    }
    
    /// Handle application terminated notification
    private func handleApplicationTerminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let pid = app.processIdentifier
        
        // Notify delegate
        let event = WindowEvent(type: .appTerminated, pid: pid)
        delegate?.handleWindowEvent(event)
        
        // Clean up observer for this process
        if let observer = observers[pid] {
            accessibilityService.stopObserving(observer)
            observers.removeValue(forKey: pid)
        }
        
        // Remove windows belonging to this process
        let windowsToRemove = observedWindows.filter { $0.value.pid == pid }
        for (windowId, _) in windowsToRemove {
            observedWindows.removeValue(forKey: windowId)
            lastKnownWindowIds.remove(windowId)
        }
        
        // Update window list
        updateWindowList()
    }
    
    /// Handle space changed notification
    private func handleSpaceChanged(_ notification: Notification) {
        // Notify delegate
        let event = WindowEvent(type: .spaceChanged)
        delegate?.handleWindowEvent(event)
        
        // Update window list to catch windows in the new space
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateWindowList()
        }
    }
}

// MARK: - AXObserver Callback

/// Callback function for accessibility notifications
func windowEventCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    userData: UnsafeMutableRawPointer?
) {
    guard let userData = userData else { return }
    
    // Extract window ID from context
    let windowId = userData.load(as: CGWindowID.self)
    
    // Determine event type
    let eventType: WindowEventType
    switch notification as String {
    case kAXMovedNotification:
        eventType = .moved
    case kAXResizedNotification:
        eventType = .resized
    case kAXTitleChangedNotification:
        eventType = .titleChanged
    case kAXUIElementDestroyedNotification:
        eventType = .closed
    default:
        return
    }
    
    // Post to main thread for handling
    DispatchQueue.main.async {
        NotificationCenter.default.post(
            name: NSNotification.Name("YukiWindowEvent"),
            object: nil,
            userInfo: [
                "windowId": windowId,
                "eventType": eventType.rawValue
            ]
        )
    }
}

// MARK: - Extension for WindowManager

extension WindowManager: WindowObserverDelegate {
    /// Initialize window observation
    func setupWindowObservation() {
        // Create observer with self as delegate
        let windowObserver = WindowObserver(delegate: self)
        
        // Store using associated objects
        objc_setAssociatedObject(
            self,
            &WindowObserverKey,
            windowObserver,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Start observing
        windowObserver.startObserving()
    }
    
    /// Handle window events from observer
    func handleWindowEvent(_ event: WindowEvent) {
        switch event.type {
        case .created:
            if let windowId = event.windowId, let windowInfo = event.windowInfo {
                handleNewWindow(windowId: Int(windowId), windowInfo: windowInfo)
            }
            
        case .closed:
            if let windowId = event.windowId {
                handleWindowClosed(windowId: Int(windowId))
            }
            
        case .moved, .resized:
            // Only apply tiling if we're not in float mode
            if TilingEngine.shared.currentMode != .float {
                if let windowId = event.windowId {
                    // Don't reapply tiling immediately for better performance
                    debounceApplyTiling()
                }
            }
            
        case .appActivated, .appTerminated, .spaceChanged:
            // Refresh windows for major system events
            refreshWindows()
            
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
        AccessibilityService.shared.disableEnhancedUserInterface(for: window)
        
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
}

// Associated object key for the WindowObserver
private var WindowObserverKey: UInt8 = 0

// MARK: - DispatchQueue Extension for Debouncing

extension DispatchQueue {
    // Static property for tiling work item
    static var tilingWorkItem: DispatchWorkItem? = nil
}
