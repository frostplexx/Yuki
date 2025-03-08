//
//  WindowNode.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Foundation
import Cocoa

/// Represents a window in the window tree
class WindowNode: Node {
    // MARK: - Node Protocol Properties
    
    var title: String?
    var type: NodeType { .window }
    var children: [any Node] = []
    var parent: (any Node)?
    let id: UUID
    
    /// The accessibility element for this window
    let window: AXUIElement
    
    /// The system window ID from CGWindowID (optional)
    var systemWindowID: String?
    
    private struct AssociatedKeys {
        static var isFloatingKey = "com.yuki.windowNode.isFloatingKey"
    }
    
    /// Track whether this window is minimized
    var isMinimized: Bool = false
    
    // MARK: - Initialization
    
    /// Initialize with an accessibility element
    init(_ window: AXUIElement) {
        self.id = UUID()
        self.window = window
        self.title = window.get(Ax.titleAttr)
        self.systemWindowID = window.get(Ax.identifierAttr)
        // Check initial minimized state
        self.isMinimized = window.get(Ax.minimizedAttr) ?? false
    }
    
    
    // MARK: - Window Properties
    
    /// Returns the current position of the window
    var position: NSPoint? {
        return window.get(Ax.topLeftCornerAttr)
    }
    
    /// Returns the current size of the window
    var size: NSSize? {
        return window.get(Ax.sizeAttr)
    }
    
    /// Returns the current frame of the window
    var frame: NSRect? {
        guard let position = position, let size = size else { return nil }
        return NSRect(origin: position, size: size)
    }
    
    // MARK: - Window Operations
    
    /// Moves the window to a new position
    /// - Parameter point: The new position
    func move(to point: NSPoint) {
        window.set(Ax.topLeftCornerAttr, point)
    }
    
    /// Resizes the window
    /// - Parameter newSize: The new size
    func resize(to newSize: CGSize) {
        window.set(Ax.sizeAttr, newSize)
    }
    
    /// Sets both the position and size at once
    func setFrame(_ rect: NSRect) {
        // Skip if minimized
        if isMinimized {
            return
        }
        
        withEnhancedUserInterfaceDisabled {
//            print("Attempting to set window frame: \(rect)")
            let result1 = window.set(Ax.sizeAttr, rect.size)
            let result2 = window.set(Ax.topLeftCornerAttr, rect.origin)
//            print("Set size result: \(result1), set position result: \(result2)")
            
            // Force a validation check
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let currentFrame = self.frame {
//                    print("Window frame after set attempt: \(currentFrame)")
                    _ = abs(currentFrame.origin.x - rect.origin.x) < 5 &&
                    abs(currentFrame.origin.y - rect.origin.y) < 5
                    _ = abs(currentFrame.size.width - rect.size.width) < 5 &&
                    abs(currentFrame.size.height - rect.size.height) < 5
//                    print("Position matches: \(positionMatches), Size matches: \(sizeMatches)")
                }
            }
        }
    }
    
    /// Brings the window to the front
    func focus() {
        if isMinimized {
            // Unminimize the window first
            toggleMinimize()
        }
        
        window.raise()
    }
    
    /// Toggles window minimized state
    func toggleMinimize() {
        let minimized = window.get(Ax.minimizedAttr) ?? false
        window.set(Ax.minimizedAttr, !minimized)
        self.isMinimized = !minimized
    }
    
    /// Toggles window fullscreen state
    func toggleFullscreen() {
        let fullscreen = window.get(Ax.isFullscreenAttr) ?? false
        window.set(Ax.isFullscreenAttr, fullscreen)
    }
    
    /// Disables the AXEnhancedUserInterface setting for this window
    func disableEnhancedUserInterface() {
        let app = AXUIElementCreateApplication(getPID(for: window))
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, false as CFTypeRef)
    }
    
    /// Enables the AXEnhancedUserInterface setting for this window
    func enableEnhancedUserInterface() {
        let app = AXUIElementCreateApplication(getPID(for: window))
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
    }
    
    /// Perform an operation with enhanced user interface temporarily disabled
    func withEnhancedUserInterfaceDisabled<T>(_ operation: () -> T) -> T {
        let wasEnabled = isEnhancedUserInterfaceEnabled(for: window) == true
        
        if wasEnabled {
            disableEnhancedUserInterface()
        }
        
        let result = operation()
        
        if wasEnabled {
            enableEnhancedUserInterface()
        }
        
        return result
    }
    
    // Property to determine if this window should always float
    var isFloating: Bool {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.isFloatingKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isFloatingKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // Toggle floating state
    @discardableResult
    func toggleFloating() -> Bool {
        isFloating = !isFloating
        return isFloating
    }
    
    /// Check if enhanced user interface is enabled for a window's application
    private func isEnhancedUserInterfaceEnabled(for window: AXUIElement) -> Bool? {
        let app = AXUIElementCreateApplication(getPID(for: window))
        
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, "AXEnhancedUserInterface" as CFString, &valueRef)
        
        guard result == .success, let value = valueRef as? Bool else {
            return nil
        }
        
        return value
    }
    
    
    private func getPID(for element: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        let error = AXUIElementGetPid(element, &pid)
        return error == .success ? pid : 0
    }
}
