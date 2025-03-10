// WindowDiscoveryService.swift
// Optimized service for window discovery and lookup

import Cocoa
import Foundation

/// Service for discovering and retrieving information about windows
class WindowDiscoveryService {
    // MARK: - Properties
    
    /// Cache for window elements to avoid repeated lookups
    private var windowCache: [CGWindowID: AXUIElement] = [:]
    
    /// Cache for window information
    private var windowInfoCache: [CGWindowID: [String: Any]] = [:]
    
    /// Cache for visible windows list
    private var cachedVisibleWindows: [[String: Any]] = []
    
    /// Timestamp of last window refresh
    private var lastWindowRefreshTime: TimeInterval = 0
    
    /// Cache timeout - how long cached windows are considered valid
    private let cacheTimeout: TimeInterval = 0.1
    
    /// Synchronization queue for thread-safe cache updates
    private let syncQueue = DispatchQueue(label: "com.yuki.windowDiscovery.sync")
    
    // MARK: - Window Discovery
    
    /// Get all visible windows on screen
    func getAllVisibleWindows() -> [[String: Any]] {
        let now = Date().timeIntervalSince1970
        
        // Return cached result if recent enough
        if now - lastWindowRefreshTime < cacheTimeout {
            return syncQueue.sync { cachedVisibleWindows }
        }
        
        // Options for getting windows
        let options = CGWindowListOption.optionOnScreenOnly.union(.excludeDesktopElements)
        
        // Get window list
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        // Filter to include only regular windows (layer 0)
        let visibleWindows = windowInfoList.filter { ($0["kCGWindowLayer"] as? Int) == 0 }
        
        // Update cache
        syncQueue.sync {
            cachedVisibleWindows = visibleWindows
            lastWindowRefreshTime = now
            
            // Update window info cache
            for windowInfo in visibleWindows {
                if let windowID = windowInfo["kCGWindowNumber"] as? Int {
                    windowInfoCache[CGWindowID(windowID)] = windowInfo
                }
            }
        }
        
        return visibleWindows
    }
    
    /// Get window info for a specific window ID
    func getWindowInfo(for windowID: CGWindowID) -> [String: Any]? {
        // Check cache first
        if let cachedInfo = syncQueue.sync(execute: { windowInfoCache[windowID] }) {
            return cachedInfo
        }
        
        // If not in cache, try to get from system
        let options = CGWindowListOption.optionOnScreenOnly.union(.excludeDesktopElements)
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        // Find window with matching ID
        let windowInfo = windowInfoList.first { windowInfo in
            guard let number = windowInfo["kCGWindowNumber"] as? Int else {
                return false
            }
            return number == Int(windowID)
        }
        
        // Update cache if found
        if let windowInfo = windowInfo {
            syncQueue.sync {
                windowInfoCache[windowID] = windowInfo
            }
        }
        
        return windowInfo
    }
    
    /// Get the accessibility element for a window ID
    func getWindowElement(for windowID: CGWindowID) -> AXUIElement? {
        // Check cache first
        if let cachedWindow = syncQueue.sync(execute: { windowCache[windowID] }) {
            return cachedWindow
        }
        
        // If not in cache, try to find it
        guard let windowInfo = getWindowInfo(for: windowID),
              let pid = windowInfo["kCGWindowOwnerPID"] as? pid_t else {
            return nil
        }
        
        // Get the application element
        let app = AXUIElementCreateApplication(pid)
        
        // Get the windows for this app
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return nil
        }
        
        // Find the window with matching ID
        for window in windows {
            var axWindowID: CGWindowID = 0
            if _AXUIElementGetWindow(window, &axWindowID) == .success, axWindowID == windowID {
                // Add to cache
                syncQueue.sync {
                    windowCache[windowID] = window
                }
                return window
            }
        }
        
        return nil
    }
    
    /// Get all windows for an application
    func getWindowsForApplication(pid: pid_t) -> [AXUIElement] {
        // Get app element
        let app = AXUIElementCreateApplication(pid)
        
        // Get app windows
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return []
        }
        
        // Filter and cache windows
        var validWindows: [AXUIElement] = []
        
        for window in windows {
            var windowID: CGWindowID = 0
            if _AXUIElementGetWindow(window, &windowID) == .success {
                syncQueue.sync {
                    windowCache[windowID] = window
                }
                validWindows.append(window)
            }
        }
        
        return validWindows
    }
    
    /// Get the window ID for an accessibility element
    func getWindowID(for window: AXUIElement) -> CGWindowID? {
        var windowID: CGWindowID = 0
        if _AXUIElementGetWindow(window, &windowID) == .success {
            return windowID
        }
        return nil
    }
    
    /// Get the title of a window
    func getWindowTitle(for window: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &valueRef) == .success,
              let title = valueRef as? String else {
            return nil
        }
        
        return title
    }
    
    /// Clear all caches
    func clearCaches() {
        syncQueue.sync {
            windowCache.removeAll()
            windowInfoCache.removeAll()
            cachedVisibleWindows.removeAll()
            lastWindowRefreshTime = 0
        }
    }
}
