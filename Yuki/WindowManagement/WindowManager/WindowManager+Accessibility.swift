//
//  WindowControls.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa
import CoreFoundation
import os
import Accessibility

// MARK: - Constants

/// Application bundle identifier
let yukiID = "com.frostplexx.Yuki"

/// Signposter for performance logging
let signposter = OSSignposter(subsystem: yukiID, category: .pointsOfInterest)

// MARK: - Private API Declarations

/// Private API for getting window ID from an accessibility element
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

// MARK: - Accessibility Utility Functions

/// Reset accessibility permissions for the application
func resetAccessibility() {
    _ = try? Process.run(URL(filePath: "/usr/bin/tccutil"), arguments: ["reset", "Accessibility", yukiID])
}

extension WindowManager {
    /// Request accessibility permissions if not already granted
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            print("Warning: Accessibility permissions are required for window management")
            // Show a user-friendly alert about accessibility permissions
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
}


/// Assert condition and log error if it fails
public func check(
    _ condition: Bool,
    _ message: @autoclosure () -> String = "",
    file: String = #fileID,
    line: Int = #line,
    column: Int = #column,
    function: String = #function
) {
    if !condition {
        // Implement error logging if needed
        // error(message(), file: file, line: line, column: column, function: function)
    }
}

// MARK: - Window Geometry Structures

/// Represents the bounds of a window with all four corners
struct WindowBounds {
    let topLeft: NSPoint
    let topRight: NSPoint
    let bottomLeft: NSPoint
    let bottomRight: NSPoint
}

// MARK: - Accessibility Attribute Protocols

/// Protocol for readable accessibility attributes
protocol ReadableAttr: Sendable {
    associatedtype T
    var getter: @Sendable (AnyObject) -> T? { get }
    var key: String { get }
}

/// Protocol for writable accessibility attributes
protocol WritableAttr: ReadableAttr, Sendable {
    var setter: @Sendable (T) -> CFTypeRef? { get }
}

// MARK: - Accessibility Attribute Implementations

/// Namespace for accessibility attributes
enum Ax {
    /// Implementation of readable attributes
    struct ReadableAttrImpl<T>: ReadableAttr {
        var key: String
        var getter: @Sendable (AnyObject) -> T?
    }

    /// Implementation of writable attributes
    struct WritableAttrImpl<T>: WritableAttr {
        var key: String
        var getter: @Sendable (AnyObject) -> T?
        var setter: @Sendable (T) -> CFTypeRef?
    }
    
    // MARK: - Window Properties
    
    /// Title attribute for windows
    static let titleAttr = WritableAttrImpl<String>(
        key: kAXTitleAttribute,
        getter: { $0 as? String },
        setter: { $0 as CFTypeRef }
    )
    
    /// Role attribute
    static let roleAttr = WritableAttrImpl<String>(
        key: kAXRoleAttribute,
        getter: { $0 as? String },
        setter: { $0 as CFTypeRef }
    )
    
    /// Subrole attribute
    static let subroleAttr = WritableAttrImpl<String>(
        key: kAXSubroleAttribute,
        getter: { $0 as? String },
        setter: { $0 as CFTypeRef }
    )
    
    /// Identifier attribute
    static let identifierAttr = ReadableAttrImpl<String>(
        key: kAXIdentifierAttribute,
        getter: { $0 as? String }
    )
    
    // MARK: - Window State
    
    /// Modal state attribute
    static let modalAttr = ReadableAttrImpl<Bool>(
        key: kAXModalAttribute,
        getter: { $0 as? Bool }
    )
    
    /// Enabled state attribute
    static let enabledAttr = ReadableAttrImpl<Bool>(
        key: kAXEnabledAttribute,
        getter: { $0 as? Bool }
    )
    
    /// Enhanced user interface attribute
    static let enhancedUserInterfaceAttr = WritableAttrImpl<Bool>(
        key: "AXEnhancedUserInterface",
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef }
    )
    
    /// Minimized state attribute
    static let minimizedAttr = WritableAttrImpl<Bool>(
        key: kAXMinimizedAttribute,
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef }
    )
    
    /// Fullscreen state attribute
    static let isFullscreenAttr = WritableAttrImpl<Bool>(
        key: "AXFullScreen",
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef }
    )
    
    /// Focus state attribute
    static let isFocused = ReadableAttrImpl<Bool>(
        key: kAXFocusedAttribute,
        getter: { $0 as? Bool }
    )
    
    /// Main window attribute
    static let isMainAttr = WritableAttrImpl<Bool>(
        key: kAXMainAttribute,
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef }
    )
    
    // MARK: - Window Geometry
    
    /// Window size attribute
    static let sizeAttr = WritableAttrImpl<CGSize>(
        key: kAXSizeAttribute,
        getter: {
            var raw: CGSize = .zero
            check(AXValueGetValue($0 as! AXValue, .cgSize, &raw))
            return raw
        },
        setter: {
            var size = $0
            return AXValueCreate(.cgSize, &size) as CFTypeRef
        }
    )
    
    /// Window position attribute
    static let topLeftCornerAttr = WritableAttrImpl<CGPoint>(
        key: kAXPositionAttribute,
        getter: {
            var raw: CGPoint = .zero
            AXValueGetValue($0 as! AXValue, .cgPoint, &raw)
            return raw
        },
        setter: {
            var point = $0
            return AXValueCreate(.cgPoint, &point) as CFTypeRef
        }
    )
    
    // MARK: - Window References
    
    /// Windows attribute - returns windows visible on all monitors
    /// If some windows are located on not active macOS Spaces then they won't be returned
    static let windowsAttr = ReadableAttrImpl<[AXUIElement]>(
        key: kAXWindowsAttribute,
        getter: { ($0 as! NSArray).compactMap(tryGetWindow) }
    )
    
    /// Focused window attribute
    static let focusedWindowAttr = ReadableAttrImpl<AXUIElement>(
        key: kAXFocusedWindowAttribute,
        getter: tryGetWindow
    )
    
    // MARK: - Window Controls
    
    /// Close button attribute
    static let closeButtonAttr = ReadableAttrImpl<AXUIElement>(
        key: kAXCloseButtonAttribute,
        getter: { ($0 as! AXUIElement) }
    )
    
    /// Fullscreen button attribute
    static let fullscreenButtonAttr = ReadableAttrImpl<AXUIElement>(
        key: kAXFullScreenButtonAttribute,
        getter: { ($0 as! AXUIElement) }
    )
    
    /// Zoom button attribute (green plus)
    static let zoomButtonAttr = ReadableAttrImpl<AXUIElement>(
        key: kAXZoomButtonAttribute,
        getter: { ($0 as! AXUIElement) }
    )
    
    /// Minimize button attribute
    static let minimizeButtonAttr = ReadableAttrImpl<AXUIElement>(
        key: kAXMinimizeButtonAttribute,
        getter: { ($0 as! AXUIElement) }
    )
}

// MARK: - Window Management Utilities

/// Tries to get a window from an accessibility element
/// - Parameter any: The potential window element
/// - Returns: A valid window AXUIElement or nil
private func tryGetWindow(_ any: Any?) -> AXUIElement? {
    guard let any else { return nil }
    let potentialWindow = any as! AXUIElement
    // Filter out non-window objects (e.g. Finder's desktop)
    return potentialWindow.containingWindowId() != nil ? potentialWindow : nil
}

