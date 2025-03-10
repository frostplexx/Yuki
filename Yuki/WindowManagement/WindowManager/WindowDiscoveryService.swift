//
//  WindowDiscoveryService.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

/// A separate service responsible for window discovery to avoid deadlocks
class WindowDiscoveryService {
    
    // Private cache for window elements
    private var windowCache: [CGWindowID: AXUIElement] = [:]
    
    private var cachedVisibleWindows: [[String: Any]] = []
    private var lastWindowRefreshTime: TimeInterval = 0
    private let cacheTimeout: TimeInterval = 0.1
    
    // Private initializer for singleton
    init() {}
    
    /// Get all visible windows on the screen
    func getAllVisibleWindows() -> [[String: Any]] {
        let now = Date().timeIntervalSince1970
        
        // Return cached result if recent enough
        if now - lastWindowRefreshTime < cacheTimeout {
            return cachedVisibleWindows
        }
        
        // Original code to get windows
        let options = CGWindowListOption.optionOnScreenOnly.union(.excludeDesktopElements)
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        let visibleWindows = windowInfoList.filter { ($0["kCGWindowLayer"] as? Int) == 0 }
        
        // Update cache
        cachedVisibleWindows = visibleWindows
        lastWindowRefreshTime = now
        
        return visibleWindows
    }
    
    /// Get window info for a specific window ID
    func getWindowInfo(for windowId: CGWindowID) -> [String: Any]? {
        // Use explicit CGWindowListOption without array literal
        let options = CGWindowListOption.optionOnScreenOnly.union(.excludeDesktopElements)
        
        // Use CGWindowListCopyWindowInfo directly
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
        
        // Cast the result
        guard let windowInfoList = windowList as? [[String: Any]] else {
            return nil
        }
        
        return windowInfoList.first { windowInfo in
            guard let number = windowInfo["kCGWindowNumber"] as? Int else {
                return false
            }
            return number == Int(windowId)
        }
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
            guard let windowId = getWindowID(for: window) else {
                return nil
            }
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
    
    /// Get the window ID for an accessibility element
    func getWindowID(for window: AXUIElement) -> CGWindowID? {
        var windowId: CGWindowID = 0
        if _AXUIElementGetWindow(window, &windowId) == .success {
            return windowId
        }
        return nil
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
}
