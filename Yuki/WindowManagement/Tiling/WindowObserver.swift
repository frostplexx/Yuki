//
//  WindowObserver.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Foundation
import Cocoa
import ApplicationServices

/// Class for observing window events and notifying the window manager
class WindowObserver {
    // MARK: - Properties
    
    /// The window manager to notify
    private weak var windowManager: WindowManager?
    
    /// Dictionary mapping window IDs to their observation tokens
    private var observationTokens: [CGWindowID: [ObservationToken]] = [:]
    
    /// Token structure for managing observations
    private struct ObservationToken {
        let element: AXUIElement
        let notification: String
        let observer: AXObserver
    }
    
    // MARK: - Initialization
    
    /// Initialize with a window manager
    /// - Parameter windowManager: The window manager to notify of events
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        
        // Start observing general window changes
        startObservingGeneralWindowChanges()
    }
    
    // MARK: - Global Window Observation
    
    /// Start observing general window changes using the workspace notification center
    private func startObservingGeneralWindowChanges() {
        // Workspace notifications
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // Application activated - might bring new windows
        notificationCenter.addObserver(
            self,
            selector: #selector(handleApplicationChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Application terminated - clean up windows
        notificationCenter.addObserver(
            self,
            selector: #selector(handleApplicationTermination),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        // Space change - update window tracking
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        
        // Also use a periodic timer to catch new windows
        Timer.scheduledTimer(
            timeInterval: 2.0,
            target: self,
            selector: #selector(periodicWindowCheck),
            userInfo: nil,
            repeats: true
        )
    }
    
    // MARK: - Event Handlers
    
    /// Handle application change notification
    @objc private func handleApplicationChange(notification: Notification) {
        // An application was activated, check for new windows
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            // Slight delay to allow windows to become available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.observeWindowsForApplication(pid: app.processIdentifier)
            }
        }
    }
    
    /// Handle application termination
    @objc private func handleApplicationTermination(notification: Notification) {
        // An application terminated, clean up its windows
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            self.cleanupWindowsForApplication(pid: app.processIdentifier)
        }
    }
    
    /// Handle space (virtual desktop) change
    @objc private func handleSpaceChange(notification: Notification) {
        // Space changed, refresh window tracking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.windowManager?.refreshWindows()
        }
    }
    
    /// Periodic check for new windows
    @objc private func periodicWindowCheck() {
        // Get the current window list
        let currentWindows = getVisibleWindowList()
        
        // Check for new windows that we aren't tracking
        for windowInfo in currentWindows {
            if let windowId = windowInfo["kCGWindowNumber"] as? Int,
               let pid = windowInfo["kCGWindowOwnerPID"] as? pid_t {
                // If we don't have observers for this window, set them up
                if !observationTokens.keys.contains(CGWindowID(windowId)) {
                    // Try to get the window element
                    if let windowElement = getWindowElement(for: pid, windowId: windowId) {
                        observeWindow(windowElement, windowId: CGWindowID(windowId))
                    }
                }
            }
        }
        
        // Refresh window manager
        windowManager?.checkForWindowChanges()
    }
    
    // MARK: - Window Observation
    
    /// Observe windows for a specific application
    /// - Parameter pid: The process ID of the application
    private func observeWindowsForApplication(pid: pid_t) {
        // Get the accessibility element for the application
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get all windows for this application
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement]
        else { return }
        
        // Set up observers for each window
        for window in windows {
            // Get the window ID
            var windowId: CGWindowID = 0
            if _AXUIElementGetWindow(window, &windowId) == .success {
                observeWindow(window, windowId: windowId)
            }
        }
    }
    
    /// Clean up windows for a terminated application
    /// - Parameter pid: The process ID of the terminated application
    private func cleanupWindowsForApplication(pid: pid_t) {
        // Get the window list from CGWindowList
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
            return
        }
        
        // Find windows owned by this application
        let appWindows = windowList.filter { ($0["kCGWindowOwnerPID"] as? pid_t) == pid }
        
        // Remove observers and notify window manager
        for windowInfo in appWindows {
            if let windowId = windowInfo["kCGWindowNumber"] as? Int {
                removeObserversForWindow(CGWindowID(windowId))
                windowManager?.handleWindowClosed(windowId: windowId)
            }
        }
    }
    
    /// Observe a specific window for events
    /// - Parameters:
    ///   - window: The window element to observe
    ///   - windowId: The window ID
    private func observeWindow(_ window: AXUIElement, windowId: CGWindowID) {
        // Check if we're already observing this window
        if observationTokens[windowId] != nil {
            return
        }
        
        // Create an observer for this window's process
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else {
            return
        }
        
        var observer: AXObserver?
        let createResult = AXObserverCreate(pid, observerCallback, &observer)
        
        guard createResult == .success, let axObserver = observer else {
            return
        }
        
        // Set up notification tokens
        var tokens: [ObservationToken] = []
        
        // Observe window moved
        if addObserver(axObserver, window, kAXMovedNotification as CFString) {
            tokens.append(ObservationToken(
                element: window,
                notification: kAXMovedNotification as String,
                observer: axObserver
            ))
        }
        
        // Observe window resized
        if addObserver(axObserver, window, kAXResizedNotification as CFString) {
            tokens.append(ObservationToken(
                element: window,
                notification: kAXResizedNotification as String,
                observer: axObserver
            ))
        }
        
        // Observe window title change
        if addObserver(axObserver, window, kAXTitleChangedNotification as CFString) {
            tokens.append(ObservationToken(
                element: window,
                notification: kAXTitleChangedNotification as String,
                observer: axObserver
            ))
        }
        
        // Observe window destruction
        if addObserver(axObserver, window, kAXUIElementDestroyedNotification as CFString) {
            tokens.append(ObservationToken(
                element: window,
                notification: kAXUIElementDestroyedNotification as String,
                observer: axObserver
            ))
        }
        
        // Store the tokens
        if !tokens.isEmpty {
            observationTokens[windowId] = tokens
            
            // Start the observer run loop source
            let runLoopSource = AXObserverGetRunLoopSource(axObserver)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
            
            print("Started observing window \(windowId)")
        }
    }
    
    /// Helper to add an observer for a specific notification
    /// - Parameters:
    ///   - observer: The accessibility observer
    ///   - element: The element to observe
    ///   - notification: The notification to observe
    /// - Returns: Whether the observer was added successfully
    private func addObserver(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString) -> Bool {
        let error = AXObserverAddNotification(observer, element, notification, UnsafeMutableRawPointer(bitPattern: Int(notification.hashValue)))
        return error == .success
    }
    
    /// Remove observers for a window
    /// - Parameter windowId: The window ID
    private func removeObserversForWindow(_ windowId: CGWindowID) {
        // Get the tokens for this window
        guard let tokens = observationTokens[windowId] else {
            return
        }
        
        // Remove each observer
        for token in tokens {
            AXObserverRemoveNotification(token.observer, token.element, token.notification as CFString)
        }
        
        // Remove the tokens
        observationTokens.removeValue(forKey: windowId)
        
        print("Stopped observing window \(windowId)")
    }
    
    // MARK: - Utilities
    
    /// Gets a visible window list from the system
    /// - Returns: Array of window info dictionaries
    private func getVisibleWindowList() -> [[String: Any]] {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
            return []
        }
        
        return windowList.filter { ($0["kCGWindowLayer"] as? Int) == 0 }
    }
    
    /// Gets a window element for a specific window ID
    /// - Parameters:
    ///   - pid: The process ID of the window's application
    ///   - windowId: The window ID
    /// - Returns: The window element if found
    private func getWindowElement(for pid: pid_t, windowId: Int) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        
        // Get all windows for this application
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement]
        else { return nil }
        
        // Find the window with the matching ID
        for window in windows {
            var windowIdValue: CGWindowID = 0
            if _AXUIElementGetWindow(window, &windowIdValue) == .success,
               windowIdValue == CGWindowID(windowId) {
                return window
            }
        }
        
        return nil
    }
}

// MARK: - AX Observer Callback

/// Callback function for accessibility notifications
func observerCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    userData: UnsafeMutableRawPointer?
) {
    // Get the window ID from the element
    var windowId: CGWindowID = 0
    let result = _AXUIElementGetWindow(element, &windowId)
    
    guard result == .success else {
        return
    }
    
    // Handle different notification types
    let notificationString = notification as String
    
    // Post a notification to handle this event on the main thread
    DispatchQueue.main.async {
        NotificationCenter.default.post(
            name: Notification.Name("WindowEvent"),
            object: nil,
            userInfo: [
                "windowId": Int(windowId),
                "eventType": notificationString
            ]
        )
    }
}

// MARK: - WindowManager Extension

extension WindowManager {
    /// Set up window observation
    func setupWindowObservation() {
        // Create the observer
        let observer = WindowObserver(windowManager: self)
        
        // Store it using associated objects
        objc_setAssociatedObject(
            self,
            &WindowObserverKey,
            observer,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Listen for window events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowEvent),
            name: Notification.Name("WindowEvent"),
            object: nil
        )
    }
    
    /// Handle a window event notification
    @objc private func handleWindowEvent(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let windowId = userInfo["windowId"] as? Int,
              let eventType = userInfo["eventType"] as? String
        else { return }
        
        // Handle the event based on type
        switch eventType {
        case kAXMovedNotification:
            handleWindowMoved(windowId: windowId)
            
        case kAXResizedNotification:
            handleWindowResized(windowId: windowId)
            
        case kAXUIElementDestroyedNotification:
            handleWindowClosed(windowId: windowId)
            
        default:
            break
        }
    }
    
    /// Handle window moved event
    func handleWindowMoved(windowId: Int) {
        // Apply tiling if auto-tiling is enabled and not in float mode
        if autoTilingController.isAutoTilingEnabled() &&
           TilingManager.shared.getCurrentMode() != .float {
            applyCurrentTiling()
        }
    }
    
    /// Handle window resized event
    func handleWindowResized(windowId: Int) {
        // Apply tiling if auto-tiling is enabled and not in float mode
        if autoTilingController.isAutoTilingEnabled() &&
           TilingManager.shared.getCurrentMode() != .float {
            applyCurrentTiling()
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
            
            print("Stopped tracking window \(windowId)")
            
            // Apply tiling to reposition remaining windows
            if autoTilingController.isAutoTilingEnabled() &&
               TilingManager.shared.getCurrentMode() != .float {
                if let monitor = workspace.monitor {
                    TilingManager.shared.applyTiling(to: workspace, on: monitor)
                }
            }
        }
    }
    
    /// Check for new windows or closed windows
    func checkForWindowChanges() {
        // Get the current window list
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
            return
        }
        
        let visibleWindows = windowList.filter { ($0["kCGWindowLayer"] as? Int) == 0 }
        
        // Check for new windows
        for windowInfo in visibleWindows {
            if let windowId = windowInfo["kCGWindowNumber"] as? Int,
               windowOwnership[windowId] == nil {
                // New untracked window found, refresh to add it
                refreshWindows()
                break
            }
        }
        
        // Check for closed windows that we're still tracking
        let currentWindowIds = Set(visibleWindows.compactMap { $0["kCGWindowNumber"] as? Int })
        let trackedWindowIds = Set(windowOwnership.keys)
        
        // Find windows we're tracking that no longer exist
        let closedWindowIds = trackedWindowIds.subtracting(currentWindowIds)
        
        // Handle each closed window
        for windowId in closedWindowIds {
            handleWindowClosed(windowId: windowId)
        }
    }
}

// Associated object key
private var WindowObserverKey: UInt8 = 0
