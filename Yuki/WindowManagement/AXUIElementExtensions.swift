//
//  AXUIElementExtensions.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa

// MARK: - AXUIElement Extensions

extension AXUIElement {
    /// Get the process ID of the app that owns this element
    func pid() -> pid_t {
        var pid: pid_t = 0
        let error = AXUIElementGetPid(self, &pid)
        return error == .success ? pid : 0
    }
    
    /// Disables enhanced user interface attribute for this element
    /// - Returns: Whether the operation was successful
    @discardableResult
    func disableEnhancedUserInterface() -> Bool {
        return set(Ax.enhancedUserInterfaceAttr, false)
    }
    
    /// Enables enhanced user interface attribute for this element
    /// - Returns: Whether the operation was successful
    @discardableResult
    func enableEnhancedUserInterface() -> Bool {
        return set(Ax.enhancedUserInterfaceAttr, true)
    }
    
    /// Gets the current enhanced user interface state
    /// - Returns: Current state, or nil if not available
    func isEnhancedUserInterfaceEnabled() -> Bool? {
        return get(Ax.enhancedUserInterfaceAttr)
    }
    
    /// Performs an operation with enhanced user interface temporarily disabled
    /// - Parameter operation: The operation to perform
    /// - Returns: The result of the operation
    func withEnhancedUserInterfaceDisabled<T>(_ operation: () -> T) -> T {
        let wasEnabled = isEnhancedUserInterfaceEnabled() == true
        
        if wasEnabled {
            disableEnhancedUserInterface()
        }
        
        let result = operation()
        
        if wasEnabled {
            enableEnhancedUserInterface()
        }
        
        return result
    }
}

// MARK: - Accessibility Helper Functions

/// Helper function to get a value from an accessibility element with proper error handling
func getAXUIElementValue<T>(_ element: AXUIElement, _ attribute: String) -> T? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    
    guard result == .success, let unwrappedValue = value else {
        return nil
    }
    
    return unwrappedValue as? T
}

/// Helper function to set a value on an accessibility element with proper error handling
@discardableResult
func setAXUIElementValue(_ element: AXUIElement, _ attribute: String, _ value: Any) -> Bool {
    let result = AXUIElementSetAttributeValue(element, attribute as CFString, value as CFTypeRef)
    return result == .success
}

extension AXUIElement {
    /// Get an accessibility attribute value
    /// - Parameters:
    ///   - attr: The attribute to retrieve
    ///   - signpostEvent: Optional signpost event name for performance tracking
    ///   - function: Function name for logging (default: calling function)
    /// - Returns: The attribute value or nil if not available
    func get<Attr: ReadableAttr>(_ attr: Attr, signpostEvent: String? = nil, function: String = #function) -> Attr.T? {
        let state = signposter.beginInterval("AXUIElement.get", "\(function): \(signpostEvent ?? "")")
        defer {
            signposter.endInterval("AXUIElement.get", state)
        }
        var raw: AnyObject?
        return AXUIElementCopyAttributeValue(self, attr.key as CFString, &raw) == .success ? attr.getter(raw!) : nil
    }

    /// Set an accessibility attribute value
    /// - Parameters:
    ///   - attr: The attribute to set
    ///   - value: The new value
    /// - Returns: Whether the operation was successful
    @discardableResult
    func set<Attr: WritableAttr>(_ attr: Attr, _ value: Attr.T) -> Bool {
        guard let value = attr.setter(value) else { return false }
        return AXUIElementSetAttributeValue(self, attr.key as CFString, value) == .success
    }

    /// Get the window ID containing this element
    /// - Parameters:
    ///   - signpostEvent: Optional signpost event name for performance tracking
    ///   - function: Function name for logging (default: calling function)
    /// - Returns: The window ID or nil if not available
    func containingWindowId(signpostEvent: String? = nil, function: String = #function) -> CGWindowID? {
        let state = signposter.beginInterval("AXUIElement.containingWindowId", "\(function): \(signpostEvent ?? "")")
        defer {
            signposter.endInterval("AXUIElement.containingWindowId", state)
        }
        var cgWindowId = CGWindowID()
        return _AXUIElementGetWindow(self, &cgWindowId) == .success ? cgWindowId : nil
    }

    /// Get the center point of the element
    var center: CGPoint? {
        guard let topLeft = get(Ax.topLeftCornerAttr) else { return nil }
        guard let size = get(Ax.sizeAttr) else { return nil }
        return CGPoint(x: topLeft.x + size.width / 2, y: topLeft.y + size.height / 2)
    }

    /// Bring the window to the front
    /// - Returns: Whether the operation was successful
    @discardableResult
    func raise() -> Bool {
        AXUIElementPerformAction(self, kAXRaiseAction as CFString) == AXError.success
    }
}

