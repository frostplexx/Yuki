//
//  WindowManagerUtility.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa

/// Utility class with helper methods for window management
class WindowManagerUtility {
    // MARK: - Window Management Utilities
    
    /// Gets all visible windows on the screen
    /// - Returns: Array of window info dictionaries
    static func getAllVisibleWindows() -> [[String: Any]] {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
            return []
        }
        
        // Filter to just visible windows (layer 0)
        return windowList.filter {
            ($0["kCGWindowLayer"] as? Int) == 0
        }
    }
    
    /// Gets the stacking order of windows (front to back)
    /// - Returns: Array of window IDs in stacking order
    static func getWindowStackingOrder() -> [Int] {
        let windows = getAllVisibleWindows()
        
        // Extract window IDs in order from the list
        return windows.compactMap { $0["kCGWindowNumber"] as? Int }
    }
    
    /// Determines which monitor contains a given point
    /// - Parameter point: The point to check
    /// - Parameter monitors: Available monitors
    /// - Returns: The monitor containing the point, or nil if none
    static func monitorContaining(point: NSPoint, in monitors: [Monitor]) -> Monitor? {
        return monitors.first { $0.contains(point: point) }
    }
    
    /// Gets information about a window by ID
    /// - Parameter windowId: The window ID to look up
    /// - Returns: Window info dictionary if found
    static func getWindowInfo(for windowId: Int) -> [String: Any]? {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
            return nil
        }
        
        return windowList.first { ($0["kCGWindowNumber"] as? Int) == windowId }
    }
    
    /// Gets the bounds of a window by ID
    /// - Parameter windowId: The window ID to look up
    /// - Returns: The window bounds if found
    static func getWindowBounds(for windowId: Int) -> CGRect? {
        guard let windowInfo = getWindowInfo(for: windowId),
              let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
              let x = bounds["X"] as? CGFloat,
              let y = bounds["Y"] as? CGFloat,
              let width = bounds["Width"] as? CGFloat,
              let height = bounds["Height"] as? CGFloat else {
            return nil
        }
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// Gets the process ID for a window ID
    /// - Parameter windowId: The window ID to look up
    /// - Returns: The process ID if found
    static func getProcessId(for windowId: Int) -> pid_t? {
        guard let windowInfo = getWindowInfo(for: windowId),
              let pid = windowInfo["kCGWindowOwnerPID"] as? pid_t else {
            return nil
        }
        
        return pid
    }
    
    /// Gets the accessibility element for a window ID
    /// - Parameter windowId: The window ID to look up
    /// - Returns: The accessibility element if found
    static func getAccessibilityElement(for windowId: Int) -> AXUIElement? {
        guard let pid = getProcessId(for: windowId) else {
            return nil
        }
        
        let app = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return nil
        }
        
        for window in windows {
            var windowIdRef: CGWindowID = 0
            if _AXUIElementGetWindow(window, &windowIdRef) == .success,
               windowIdRef == CGWindowID(windowId) {
                return window
            }
        }
        
        return nil
    }
}
