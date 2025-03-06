//
//  WindowObserver.swift
//  Yuki
//
//  Created by Claude AI on 6/3/25.
//

//import ApplicationServices
//import Cocoa
//import os
//
///// Types of window events that can be observed
//enum WindowEventType: String {
//    case created = "created"
//    case closed = "closed"
//    case moved = "moved"
//    case resized = "resized"
//    case titleChanged = "titleChanged"
//    case minimized = "minimized"
//    case unminimized = "unminimized"
//    case focused = "focused"
//    case appActivated = "appActivated"
//    case appTerminated = "appTerminated"
//    case spaceChanged = "spaceChanged"
//}
//
///// Structure representing a window event
//struct WindowEvent {
//    let type: WindowEventType
//    let windowId: CGWindowID?
//    let pid: pid_t?
//    let timestamp: Date
//    let windowInfo: [String: Any]?
//
//    init(
//        type: WindowEventType, windowId: CGWindowID? = nil, pid: pid_t? = nil,
//        windowInfo: [String: Any]? = nil
//    ) {
//        self.type = type
//        self.windowId = windowId
//        self.pid = pid
//        self.timestamp = Date()
//        self.windowInfo = windowInfo
//    }
//}
//
///// Protocol for window event handlers
//protocol WindowObserverDelegate: AnyObject {
//    func handleWindowEvent(_ event: WindowEvent)
//}
//
///// Class for observing window events efficiently
//class WindowObserver {
//    // MARK: - Properties
//
//    /// Delegate to handle window events
//    weak var delegate: WindowObserverDelegate?
//
//    /// Logger for debugging and performance tracking
//    private let logger = Logger(
//        subsystem: "com.frostplexx.Yuki", category: "WindowObserver")
//
//    /// Accessibility service reference
//    private let accessibilityService = AccessibilityService.shared
//
//    /// Dictionary mapping window IDs to their observation tokens
//    private var observedWindows: [CGWindowID: ObservationToken] = [:]
//
//    /// Dictionary mapping process IDs to their AXObservers
//    private var observers: [pid_t: AXObserver] = [:]
//
//    /// Structure to track observation tokens
//    private struct ObservationToken {
//        let element: AXUIElement
//        let pid: pid_t
//    }
//
//    /// Notification center token for workspace notifications
//    private var workspaceNotificationTokens: [NSObjectProtocol] = []
//
//    /// Set of newly created window IDs to avoid duplicate events
//    private var newlyCreatedWindows = Set<CGWindowID>()
//
//    /// Last known window list for detecting new and closed windows
//    private var lastKnownWindowIds = Set<CGWindowID>()
//
//    // MARK: - Initialization and Cleanup
//
//    init(delegate: WindowObserverDelegate) {
//        self.delegate = delegate
//        setupWorkspaceNotifications()
//        registerForAdditionalNotifications()
//    }
//
//    deinit {
//        stopObserving()
//    }
//
//    // MARK: - Public Methods
//
//    /// Start observing all windows
//    func startObserving() {
//        // Start with a clean slate
//        stopObserving()
//
//        // First fetch all current windows
//        updateWindowList()
//
//        // Schedule periodic window list refresh (at a reasonable interval)
//        // This is a fallback to catch any windows we might miss with the event-based approach
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
//            self?.updateWindowList()
//        }
//
//        // Enhanced initial detection
//        enhanceInitialWindowDetection()
//    }
//
//    /// Stop observing all windows
//    func stopObserving() {
//        // Clean up window observation
//        for (_, token) in observedWindows {
//            if let observer = observers[token.pid] {
//                accessibilityService.stopObserving(observer)
//            }
//        }
//
//        // Clean up observers
//        observers.removeAll()
//        observedWindows.removeAll()
//
//        // Remove workspace notification tokens
//        for token in workspaceNotificationTokens {
//            NotificationCenter.default.removeObserver(token)
//        }
//        workspaceNotificationTokens.removeAll()
//    }
//
//    /// Force refresh of the window list
//    func refreshWindowList() {
//        updateWindowList()
//    }
//
//    /// Scan for new windows more frequently during initial period
//    func enhanceInitialWindowDetection() {
//        // Initial window scan schedule with decreasing frequency
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//            self?.updateWindowList()
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                [weak self] in
//                self?.updateWindowList()
//
//                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                    [weak self] in
//                    self?.updateWindowList()
//                }
//            }
//        }
//    }
//
//    /// Force a complete refresh of all window tracking
//    func forceWindowRefresh() {
//        // Clear tracking information
//        lastKnownWindowIds.removeAll()
//
//        // Get all windows and notify about them
//        let currentWindows = accessibilityService.getAllVisibleWindows()
//        for windowInfo in currentWindows {
//            if let windowId = windowInfo["kCGWindowNumber"] as? Int {
//                let cgWindowId = CGWindowID(windowId)
//
//                // Treat all as new windows
//                if !newlyCreatedWindows.contains(cgWindowId) {
//                    handleNewWindow(
//                        windowId: cgWindowId, windowInfo: windowInfo)
//                }
//            }
//        }
//
//        // Update tracking state
//        lastKnownWindowIds = Set(
//            currentWindows.compactMap {
//                $0["kCGWindowNumber"] as? Int
//            }.map { CGWindowID($0) })
//    }
//
//    // MARK: - Private Methods
//
//    /// Register for additional system notifications to catch window changes
//    func registerForAdditionalNotifications() {
//        // Listen for application launches
//        let appLaunchedToken = NSWorkspace.shared.notificationCenter
//            .addObserver(
//                forName: NSWorkspace.didLaunchApplicationNotification,
//                object: nil,
//                queue: .main
//            ) { [weak self] notification in
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                    self?.forceWindowRefresh()
//                }
//            }
//        workspaceNotificationTokens.append(appLaunchedToken)
//
//        // Listen for screen parameter changes (which might indicate window changes)
//        let screenChangeToken = NotificationCenter.default.addObserver(
//            forName: NSApplication.didChangeScreenParametersNotification,
//            object: nil,
//            queue: .main
//        ) { [weak self] _ in
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                self?.forceWindowRefresh()
//            }
//        }
//        workspaceNotificationTokens.append(screenChangeToken)
//
//        // Listen for internal window events
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(handleWindowNotification),
//            name: NSNotification.Name("YukiWindowEvent"),
//            object: nil
//        )
//    }
//
//    /// Setup notifications from the workspace
//    private func setupWorkspaceNotifications() {
//        let notificationCenter = NSWorkspace.shared.notificationCenter
//
//        // Application activated
//        let appActivatedToken = notificationCenter.addObserver(
//            forName: NSWorkspace.didActivateApplicationNotification,
//            object: nil,
//            queue: .main
//        ) { [weak self] notification in
//            self?.handleApplicationActivated(notification)
//        }
//        workspaceNotificationTokens.append(appActivatedToken)
//
//        // Application terminated
//        let appTerminatedToken = notificationCenter.addObserver(
//            forName: NSWorkspace.didTerminateApplicationNotification,
//            object: nil,
//            queue: .main
//        ) { [weak self] notification in
//            self?.handleApplicationTerminated(notification)
//        }
//        workspaceNotificationTokens.append(appTerminatedToken)
//
//        // Space changed
//        let spaceChangedToken = notificationCenter.addObserver(
//            forName: NSWorkspace.activeSpaceDidChangeNotification,
//            object: nil,
//            queue: .main
//        ) { [weak self] notification in
//            self?.handleSpaceChanged(notification)
//        }
//        workspaceNotificationTokens.append(spaceChangedToken)
//    }
//
//    /// Handle window notification from callback
//    @objc private func handleWindowNotification(_ notification: Notification) {
//        guard let userInfo = notification.userInfo,
//            let windowIdValue = userInfo["windowId"] as? CGWindowID,
//            let eventTypeString = userInfo["eventType"] as? String,
//            let eventType = WindowEventType(rawValue: eventTypeString)
//        else {
//            return
//        }
//
//        switch eventType {
//        case .moved:
//            handleWindowMovedEvent(windowId: windowIdValue)
//        case .resized:
//            // Create resized event
//            let event = WindowEvent(type: .resized, windowId: windowIdValue)
//            delegate?.handleWindowEvent(event)
//        case .closed:
//            handleClosedWindow(windowId: windowIdValue)
//        default:
//            // Pass through other events
//            let event = WindowEvent(type: eventType, windowId: windowIdValue)
//            delegate?.handleWindowEvent(event)
//        }
//    }
//
//    /// Update the list of windows and detect changes
//    private func updateWindowList() {
//        // Get current window list
//        let currentWindows = accessibilityService.getAllVisibleWindows()
//
//        // Create set of current window IDs
//        let currentWindowIds = Set(
//            currentWindows.compactMap { $0["kCGWindowNumber"] as? Int }.map {
//                CGWindowID($0)
//            })
//
//        // Find new windows (current - last known)
//        let newWindowIds = currentWindowIds.subtracting(lastKnownWindowIds)
//            .subtracting(newlyCreatedWindows)
//
//        // Find closed windows (last known - current)
//        let closedWindowIds = lastKnownWindowIds.subtracting(currentWindowIds)
//
//        // Handle new windows
//        for windowId in newWindowIds {
//            if let windowInfo = currentWindows.first(where: {
//                ($0["kCGWindowNumber"] as? Int) == Int(windowId)
//            }) {
//                handleNewWindow(windowId: windowId, windowInfo: windowInfo)
//            }
//        }
//
//        // Handle closed windows
//        for windowId in closedWindowIds {
//            handleClosedWindow(windowId: windowId)
//        }
//
//        // Update last known window list
//        lastKnownWindowIds = currentWindowIds
//
//        // Clear newly created windows set (they're now in lastKnownWindowIds)
//        newlyCreatedWindows.removeAll()
//
//        // Schedule next update with a reasonable interval
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
//            self?.updateWindowList()
//        }
//    }
//
//    /// Handle a new window being detected
//    private func handleNewWindow(
//        windowId: CGWindowID, windowInfo: [String: Any]
//    ) {
//        guard let pid = windowInfo["kCGWindowOwnerPID"] as? pid_t else {
//            return
//        }
//
//        // Add to newly created windows set
//        newlyCreatedWindows.insert(windowId)
//
//        // Create window observation
//        if let windowElement = accessibilityService.getWindowElement(
//            for: windowId)
//        {
//            observeWindow(windowElement, windowId: windowId, pid: pid)
//
//            // Notify delegate
//            let event = WindowEvent(
//                type: .created, windowId: windowId, pid: pid,
//                windowInfo: windowInfo)
//            delegate?.handleWindowEvent(event)
//        }
//    }
//
//    /// Handle a window being closed
//    private func handleClosedWindow(windowId: CGWindowID) {
//        // Remove observation
//        if let token = observedWindows[windowId] {
//            if let observer = observers[token.pid] {
//                // Remove notifications for this window
//                accessibilityService.removeNotification(
//                    kAXMovedNotification, from: token.element, for: observer)
//                accessibilityService.removeNotification(
//                    kAXResizedNotification, from: token.element, for: observer)
//                accessibilityService.removeNotification(
//                    kAXTitleChangedNotification, from: token.element,
//                    for: observer)
//                accessibilityService.removeNotification(
//                    kAXUIElementDestroyedNotification, from: token.element,
//                    for: observer)
//            }
//
//            // Remove from observed windows
//            observedWindows.removeValue(forKey: windowId)
//        }
//
//        // Notify delegate
//        let event = WindowEvent(type: .closed, windowId: windowId)
//        delegate?.handleWindowEvent(event)
//    }
//
//    /// Handle window moved event with special handling for pinning
//    func handleWindowMovedEvent(windowId: CGWindowID) {
//        // Notify delegate about the move
//        let event = WindowEvent(type: .moved, windowId: windowId)
//        delegate?.handleWindowEvent(event)
//    }
//
//    /// Observe a specific window for events
//    private func observeWindow(
//        _ window: AXUIElement, windowId: CGWindowID, pid: pid_t
//    ) {
//        // Check if we're already observing this window
//        if observedWindows[windowId] != nil {
//            return
//        }
//
//        // Get or create observer for this process
//        let observer: AXObserver
//        if let existingObserver = observers[pid] {
//            observer = existingObserver
//        } else if let newObserver = accessibilityService.createObserver(
//            for: pid, callback: windowEventCallback)
//        {
//            observer = newObserver
//            observers[pid] = observer
//            accessibilityService.startObserving(observer)
//        } else {
//            return
//        }
//
//        // Create context pointers for different notifications
//        let movedContext = UnsafeMutableRawPointer.allocate(
//            byteCount: MemoryLayout<CGWindowID>.size,
//            alignment: MemoryLayout<CGWindowID>.alignment)
//        movedContext.storeBytes(of: windowId, as: CGWindowID.self)
//
//        let resizedContext = UnsafeMutableRawPointer.allocate(
//            byteCount: MemoryLayout<CGWindowID>.size,
//            alignment: MemoryLayout<CGWindowID>.alignment)
//        resizedContext.storeBytes(of: windowId, as: CGWindowID.self)
//
//        let titleContext = UnsafeMutableRawPointer.allocate(
//            byteCount: MemoryLayout<CGWindowID>.size,
//            alignment: MemoryLayout<CGWindowID>.alignment)
//        titleContext.storeBytes(of: windowId, as: CGWindowID.self)
//
//        let destroyedContext = UnsafeMutableRawPointer.allocate(
//            byteCount: MemoryLayout<CGWindowID>.size,
//            alignment: MemoryLayout<CGWindowID>.alignment)
//        destroyedContext.storeBytes(of: windowId, as: CGWindowID.self)
//
//        // Add notifications to observer
//        accessibilityService.addNotification(
//            kAXMovedNotification, to: window, for: observer,
//            userData: movedContext)
//        accessibilityService.addNotification(
//            kAXResizedNotification, to: window, for: observer,
//            userData: resizedContext)
//        accessibilityService.addNotification(
//            kAXTitleChangedNotification, to: window, for: observer,
//            userData: titleContext)
//        accessibilityService.addNotification(
//            kAXUIElementDestroyedNotification, to: window, for: observer,
//            userData: destroyedContext)
//
//        // Store token
//        observedWindows[windowId] = ObservationToken(element: window, pid: pid)
//    }
//
//    // MARK: - Workspace Notification Handlers
//
//    /// Handle application activated notification
//    private func handleApplicationActivated(_ notification: Notification) {
//        guard
//            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
//                as? NSRunningApplication
//        else {
//            return
//        }
//
//        // Notify delegate
//        let event = WindowEvent(type: .appActivated, pid: app.processIdentifier)
//        delegate?.handleWindowEvent(event)
//
//        // Update window list to catch new windows
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//            self?.updateWindowList()
//        }
//    }
//
//    /// Handle application terminated notification
//    private func handleApplicationTerminated(_ notification: Notification) {
//        guard
//            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
//                as? NSRunningApplication
//        else {
//            return
//        }
//
//        let pid = app.processIdentifier
//
//        // Notify delegate
//        let event = WindowEvent(type: .appTerminated, pid: pid)
//        delegate?.handleWindowEvent(event)
//
//        // Clean up observer for this process
//        if let observer = observers[pid] {
//            accessibilityService.stopObserving(observer)
//            observers.removeValue(forKey: pid)
//        }
//
//        // Remove windows belonging to this process
//        let windowsToRemove = observedWindows.filter { $0.value.pid == pid }
//        for (windowId, _) in windowsToRemove {
//            observedWindows.removeValue(forKey: windowId)
//            lastKnownWindowIds.remove(windowId)
//        }
//
//        // Update window list
//        updateWindowList()
//    }
//
//    /// Handle space changed notification
//    private func handleSpaceChanged(_ notification: Notification) {
//        // Notify delegate
//        let event = WindowEvent(type: .spaceChanged)
//        delegate?.handleWindowEvent(event)
//
//        // Update window list to catch windows in the new space
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
//            self?.updateWindowList()
//        }
//    }
//}
//
//// MARK: - AXObserver Callback
//
///// Callback function for accessibility notifications
//func windowEventCallback(
//    observer: AXObserver,
//    element: AXUIElement,
//    notification: CFString,
//    userData: UnsafeMutableRawPointer?
//) {
//    guard let userData = userData else { return }
//
//    // Extract window ID from context
//    let windowId = userData.load(as: CGWindowID.self)
//
//    // Determine event type
//    let eventType: String
//    switch notification as String {
//    case kAXMovedNotification:
//        eventType = WindowEventType.moved.rawValue
//    case kAXResizedNotification:
//        eventType = WindowEventType.resized.rawValue
//    case kAXTitleChangedNotification:
//        eventType = WindowEventType.titleChanged.rawValue
//    case kAXUIElementDestroyedNotification:
//        eventType = WindowEventType.closed.rawValue
//    default:
//        return
//    }
//
//    // Post to main thread for handling
//    DispatchQueue.main.async {
//        NotificationCenter.default.post(
//            name: NSNotification.Name("YukiWindowEvent"),
//            object: nil,
//            userInfo: [
//                "windowId": windowId,
//                "eventType": eventType,
//            ]
//        )
//    }
//}
//
//// For associating with WindowManager
//var WindowObserverKey: UInt8 = 0
//
//// Static property for tiling work item
//extension DispatchQueue {
//    static var tilingWorkItem: DispatchWorkItem? = nil
//}
