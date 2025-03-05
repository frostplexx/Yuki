//
//  AccessibilityService.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//


import Cocoa
import Accessibility
import os

/// Central service for all accessibility-related operations
class AccessibilityService {
    // MARK: - Singleton
    
    /// Shared instance
    static let shared = AccessibilityService()
    
    // MARK: - Properties
    
    /// Logger for performance and debugging
    private let logger = Logger(subsystem: "com.frostplexx.Yuki", category: "AccessibilityService")
    
    /// Performance signposter
    private let signposter = OSSignposter(subsystem: "com.frostplexx.Yuki", category: .pointsOfInterest)
    
    /// Application bundle identifier
    private let appIdentifier = "com.frostplexx.Yuki"
    
    /// Cache for window elements to improve performance
    private var windowCache: [CGWindowID: AXUIElement] = [:]
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Permission Management
    
    /// Request accessibility permissions if not already granted
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            logger.warning("Accessibility permissions are required for window management")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permissions Required"
                alert.informativeText = "Yuki needs accessibility permissions to manage your windows. Please grant access in System Preferences > Security & Privacy > Privacy > Accessibility."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Preferences")
                alert.addButton(withTitle: "Later")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    let prefpaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(prefpaneURL)
                }
            }
        }
    }
    
    /// Check if accessibility permissions are granted
    var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }
    
    /// Reset accessibility permissions for the application
    func resetPermissions() {
        do {
            try Process.run(URL(filePath: "/usr/bin/tccutil"), arguments: ["reset", "Accessibility", appIdentifier])
        } catch {
            logger.error("Failed to reset accessibility permissions: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Window Discovery
    
    /// Get all visible windows on the screen
    func getAllVisibleWindows() -> [[String: Any]] {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
            return []
        }
        
        // Filter to just visible windows (layer 0)
        return windowList.filter {
            ($0["kCGWindowLayer"] as? Int) == 0
        }
    }
    
    /// Get window info for a specific window ID
    func getWindowInfo(for windowId: CGWindowID) -> [String: Any]? {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
            return nil
        }
        
        return windowList.first { ($0["kCGWindowNumber"] as? Int) == Int(windowId) }
    }
    
    /// Get all windows for an application
    func getWindowsForApplication(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return []
        }
        
        // Filter out non-window objects and cache valid windows
        return windows.compactMap { window in
            guard let windowId = getWindowID(for: window) else { return nil }
            windowCache[windowId] = window
            return window
        }
    }
    
    /// Get the accessibility element for a window ID
    func getWindowElement(for windowId: CGWindowID) -> AXUIElement? {
        // Check cache first
        if let cachedWindow = windowCache[windowId] {
            return cachedWindow
        }
        
        // If not in cache, try to find it
        guard let windowInfo = getWindowInfo(for: windowId),
              let pid = windowInfo["kCGWindowOwnerPID"] as? pid_t else {
            return nil
        }
        
        let app = AXUIElementCreateApplication(pid)
        
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return nil
        }
        
        for window in windows {
            if let windowIdValue = getWindowID(for: window), windowIdValue == windowId {
                windowCache[windowId] = window
                return window
            }
        }
        
        return nil
    }
    
    // MARK: - Window Properties
    
    /// Get the window ID for an accessibility element
    func getWindowID(for window: AXUIElement) -> CGWindowID? {
        var windowId: CGWindowID = 0
        return _AXUIElementGetWindow(window, &windowId) == .success ? windowId : nil
    }
    
    /// Get the process ID for an accessibility element
    func getPID(for element: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        let error = AXUIElementGetPid(element, &pid)
        return error == .success ? pid : 0
    }
    
    /// Get the title of a window
    func getTitle(for window: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &valueRef) == .success,
              let title = valueRef as? String else {
            return nil
        }
        return title
    }
    
    /// Get the position of a window
    func getPosition(for window: AXUIElement) -> NSPoint? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &valueRef) == .success,
              let value = valueRef as! AXValue? else {
            return nil
        }
        
        var position = NSPoint.zero
        AXValueGetValue(value, .cgPoint, &position)
        return position
    }
    
    /// Get the size of a window
    func getSize(for window: AXUIElement) -> NSSize? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &valueRef) == .success,
              let value = (valueRef as! AXValue?) else {
            return nil
        }
        
        var size = NSSize.zero
        AXValueGetValue(value, .cgSize, &size)
        return size
    }
    
    /// Check if a window is minimized
    func isMinimized(for window: AXUIElement) -> Bool {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &valueRef) == .success,
              let minimized = valueRef as? Bool else {
            return false
        }
        return minimized
    }
    
    /// Check if a window is in fullscreen mode
    func isFullscreen(for window: AXUIElement) -> Bool {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &valueRef) == .success,
              let fullscreen = valueRef as? Bool else {
            return false
        }
        return fullscreen
    }
    
    // MARK: - Window Operations
    
    /// Set the position of a window
    @discardableResult
    func setPosition(_ position: NSPoint, for window: AXUIElement) -> Bool {
        let state = signposter.beginInterval("setPosition")
        defer { signposter.endInterval("setPosition", state) }
        
        var point = position
        guard let value = AXValueCreate(.cgPoint, &point) else {
            return false
        }
        
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success
    }
    
    /// Set the size of a window
    @discardableResult
    func setSize(_ size: NSSize, for window: AXUIElement) -> Bool {
        let state = signposter.beginInterval("setSize")
        defer { signposter.endInterval("setSize", state) }
        
        var sizeValue = size
        guard let value = AXValueCreate(.cgSize, &sizeValue) else {
            return false
        }
        
        return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value) == .success
    }
    
    /// Set the frame (position and size) of a window
    @discardableResult
    func setFrame(_ frame: NSRect, for window: AXUIElement, animated: Bool = false) -> Bool {
        if animated {
            return setSize(frame.size, for: window) && setPosition(frame.origin, for: window)
        }
        
        // Perform without animation by temporarily disabling enhanced user interface
        return withEnhancedUserInterfaceDisabled(for: window) {
            return setSize(frame.size, for: window) && setPosition(frame.origin, for: window)
        }
    }
    
    /// Bring a window to the front
    @discardableResult
    func raiseWindow(_ window: AXUIElement) -> Bool {
        return AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success
    }
    
    /// Toggle window minimized state
    @discardableResult
    func toggleMinimize(for window: AXUIElement) -> Bool {
        let minimized = isMinimized(for: window)
        return AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, (!minimized) as CFTypeRef) == .success
    }

    /// Toggle window fullscreen state
    @discardableResult
    func toggleFullscreen(for window: AXUIElement) -> Bool {
        let fullscreen = isFullscreen(for: window)
        return AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, (!fullscreen) as CFTypeRef) == .success
    }
    // MARK: - Enhanced User Interface Management
    
    /// Check if enhanced user interface is enabled for a window's application
    func isEnhancedUserInterfaceEnabled(for window: AXUIElement) -> Bool? {
        let app = AXUIElementCreateApplication(getPID(for: window))
        
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, "AXEnhancedUserInterface" as CFString, &valueRef)
        
        guard result == .success, let value = valueRef as? Bool else {
            return nil
        }
        
        return value
    }
    
    /// Enable enhanced user interface for a window's application
    @discardableResult
    func enableEnhancedUserInterface(for window: AXUIElement) -> Bool {
        let app = AXUIElementCreateApplication(getPID(for: window))
        return AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, true as CFTypeRef) == .success
    }
    
    /// Disable enhanced user interface for a window's application
    @discardableResult
    func disableEnhancedUserInterface(for window: AXUIElement) -> Bool {
        let app = AXUIElementCreateApplication(getPID(for: window))
        return AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, false as CFTypeRef) == .success
    }
    
    /// Perform an operation with enhanced user interface temporarily disabled
    func withEnhancedUserInterfaceDisabled<T>(for window: AXUIElement, _ operation: () -> T) -> T {
        let wasEnabled = isEnhancedUserInterfaceEnabled(for: window) == true
        
        if wasEnabled {
            disableEnhancedUserInterface(for: window)
        }
        
        let result = operation()
        
        if wasEnabled {
            enableEnhancedUserInterface(for: window)
        }
        
        return result
    }
    
    // MARK: - Observer Management
    
    /// Create an accessibility observer for a specific process
    func createObserver(for pid: pid_t, callback: @escaping AXObserverCallback) -> AXObserver? {
        var observer: AXObserver?
        let result = AXObserverCreate(pid, callback, &observer)
        
        guard result == .success, let axObserver = observer else {
            logger.error("Failed to create AXObserver for process \(pid): \(result.rawValue)")
            return nil
        }
        
        return axObserver
    }
    
    /// Add a notification to an observer for a specific element
    @discardableResult
    func addNotification(_ notification: String, to element: AXUIElement, for observer: AXObserver, userData: UnsafeMutableRawPointer? = nil) -> Bool {
        let result = AXObserverAddNotification(observer, element, notification as CFString, userData)
        if result != .success {
            logger.error("Failed to add notification \(notification) to observer: \(result.rawValue)")
        }
        return result == .success
    }
    
    /// Remove a notification from an observer for a specific element
    @discardableResult
    func removeNotification(_ notification: String, from element: AXUIElement, for observer: AXObserver) -> Bool {
        let result = AXObserverRemoveNotification(observer, element, notification as CFString)
        if result != .success {
            logger.error("Failed to remove notification \(notification) from observer: \(result.rawValue)")
        }
        return result == .success
    }
    
    /// Start the observer's run loop source
    func startObserving(_ observer: AXObserver) {
        let runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
    }
    
    /// Stop the observer's run loop source
    func stopObserving(_ observer: AXObserver) {
        let runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
    }
    
    // MARK: - Cache Management
    
    /// Clear the window cache
    func clearCache() {
        windowCache.removeAll()
    }
    
    /// Remove a specific window from the cache
    func removeFromCache(windowId: CGWindowID) {
        windowCache.removeValue(forKey: windowId)
    }
}
