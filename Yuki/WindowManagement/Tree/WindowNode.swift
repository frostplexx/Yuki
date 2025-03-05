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
    // MARK: Node Protocol Properties

    var title: String?
    var type: NodeType { .window }
    var children: [any Node] = []
    var parent: (any Node)?
    let id: UUID

    /// The accessibility element for this window
    let window: AXUIElement

    /// The system window ID from CGWindowID (optional)
    var systemWindowID: Int?

    /// Initialize with an accessibility element
    init(_ window: AXUIElement) {
        self.id = UUID()
        self.window = window
        self.title = window.get(Ax.titleAttr)
        //        self.systemWindowID = window.get(Ax.identifierAttr)
    }

    /// Initialize with additional metadata
    init(window: AXUIElement, systemWindowID: Int? = nil, title: String? = nil)
    {
        self.id = UUID()
        self.window = window
        self.systemWindowID = systemWindowID

        // Use provided title or try to get it from the window
        if let title = title {
            self.title = title
        } else {
            self.title = window.get(Ax.titleAttr)
        }
    }

    // MARK: Window Management Methods

    /// Returns the current position of the window
    var position: NSPoint? {
        return window.get(Ax.topLeftCornerAttr)
    }

    /// Returns the current size of the window
    var size: NSSize? {
        guard let size = window.get(Ax.sizeAttr) else { return nil }
        return NSSize(width: size.width, height: size.height)
    }

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

    /// Brings the window to the front
    func focus() {
        window.raise()
    }

    /// Toggles window minimized state
    func toggleMinimize() {
        if let minimized = window.get(Ax.minimizedAttr) {
            window.set(Ax.minimizedAttr, !minimized)
        }
    }

    /// Toggles window fullscreen state
    func toggleFullscreen() {
        if let fullscreen = window.get(Ax.isFullscreenAttr) {
            window.set(Ax.isFullscreenAttr, !fullscreen)
        }
    }

    /// Disables the AXEnhancedUserInterface setting for this window
    /// This prevents incorrect window resizing (related to issue #285)
    func disableEnhancedUserInterface() {
        window.set(Ax.enhancedUserInterfaceAttr, false)
    }

    /// Enables the AXEnhancedUserInterface setting for this window
    func enableEnhancedUserInterface() {
        window.set(Ax.enhancedUserInterfaceAttr, true)
    }

    /// Resizes the window without using the native resizing which can have issues
    /// - Parameter newSize: The new size to apply
    func resizeWithoutEnhancement(to newSize: NSSize) {
        // Temporarily disable enhanced user interface
        let currentEnhancedSetting =
            window.get(Ax.enhancedUserInterfaceAttr) ?? false

        if currentEnhancedSetting {
            window.set(Ax.enhancedUserInterfaceAttr, false)
        }

        // Perform the resize
        window.set(
            Ax.sizeAttr, CGSize(width: newSize.width, height: newSize.height))

        // Restore the previous setting
        if currentEnhancedSetting {
            window.set(Ax.enhancedUserInterfaceAttr, true)
        }
    }
    
    /// Sets the position and size of the window
    /// - Parameter rect: The rectangle to position and size the window
    func setFrame(_ rect: NSRect) {
        let app = AXUIElementCreateApplication(window.pid())
        
        // Check if enhanced user interface is enabled
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, "AXEnhancedUserInterface" as CFString, &value)
        let wasEnabled = (result == .success && (value as? Bool) == true)
        
        // Disable enhanced user interface if it was enabled
        if wasEnabled {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, false as CFTypeRef)
        }
        
        // Resize and reposition
        resize(to: CGSize(width: rect.width, height: rect.height))
        move(to: NSPoint(x: rect.minX, y: rect.minY))
        
        // Restore the previous state
        if wasEnabled {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
        }
    }
}
