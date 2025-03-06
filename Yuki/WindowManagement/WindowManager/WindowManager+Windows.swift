//
//  WindowManager+Windows.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Cocoa
import Foundation

extension WindowManager {

    /// Get the process ID for an accessibility element
    func getPID(for element: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        let error = AXUIElementGetPid(element, &pid)
        return error == .success ? pid : 0
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
            guard let windowId = windowDiscovery.getWindowID(for: window) else {
                return nil
            }
            windowCache[windowId] = window
            return window
        }
    }

    //    // MARK: - Window Discovery
    //
    //    /// Minimal implementation to get all visible windows on screen
    //    func getAllVisibleWindows() -> [[String: Any]] {
    //        // Try a minimalistic approach to avoid any recursive locks
    //        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    //
    //        // Don't use any internal methods
    //        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    //            print("Failed to get window list")
    //            return []
    //        }
    //
    //        // Super simple filtering
    //        return windowInfoList.filter { info in
    //            return (info["kCGWindowLayer"] as? Int) == 0
    //        }
    //    }
    //
    //    /// Get window info for a specific window ID
    //    func getWindowInfo(for windowId: CGWindowID) -> [String: Any]? {
    //        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    //
    //        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    //            return nil
    //        }
    //
    //        return windowInfoList.first { info in
    //            return (info["kCGWindowNumber"] as? Int) == Int(windowId)
    //        }
    //    }
    //
    //    /// Get the accessibility element for a window ID
    //    func getWindowElement(for windowId: CGWindowID) -> AXUIElement? {
    //        // Check cache first (thread-safe read)
    //        if let cachedWindow = windowCache[windowId] {
    //            return cachedWindow
    //        }
    //
    //        // If not in cache, try to find it by getting window info
    //        guard let windowInfo = getWindowInfo(for: windowId),
    //              let pid = windowInfo["kCGWindowOwnerPID"] as? pid_t else {
    //            return nil
    //        }
    //
    //        // Create the accessibility element for the application
    //        let app = AXUIElementCreateApplication(pid)
    //
    //        // Try to get the windows
    //        var windowsRef: CFTypeRef?
    //        let status = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
    //
    //        if status != .success {
    //            return nil
    //        }
    //
    //        guard let windows = windowsRef as? [AXUIElement] else {
    //            return nil
    //        }
    //
    //        // Find the window with the matching ID
    //        for window in windows {
    //            var axWindowId: CGWindowID = 0
    //            if _AXUIElementGetWindow(window, &axWindowId) == .success && axWindowId == windowId {
    //                // Store in cache and return
    //                windowCache[windowId] = window
    //                return window
    //            }
    //        }
    //
    //        return nil
    //    }
    //
    //    /// Get the window ID for an accessibility element
    //    func getWindowID(for window: AXUIElement) -> CGWindowID? {
    //        var windowId: CGWindowID = 0
    //        return _AXUIElementGetWindow(window, &windowId) == .success ? windowId : nil
    //    }
}
