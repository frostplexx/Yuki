//
//  WindowNode.swift
//  Yuki
//
//  Created by Claude AI on 5/3/25.
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
    var systemWindowID: Int?
    
    /// Accessibility service for operations
    private let accessibilityService = AccessibilityService.shared
    
    // MARK: - Initialization
    
    /// Initialize with an accessibility element
    init(_ window: AXUIElement) {
        self.id = UUID()
        self.window = window
        self.title = accessibilityService.getTitle(for: window)
        self.systemWindowID = accessibilityService.getWindowID(for: window).map { Int($0) }
    }
    
    /// Initialize with additional metadata
    init(window: AXUIElement, systemWindowID: Int? = nil, title: String? = nil) {
        self.id = UUID()
        self.window = window
        self.systemWindowID = systemWindowID
        
        // Use provided title or try to get it from the window
        if let title = title {
            self.title = title
        } else {
            self.title = accessibilityService.getTitle(for: window)
        }
    }
    
    // MARK: - Window Properties
    
    /// Returns the current position of the window
    var position: NSPoint? {
        return accessibilityService.getPosition(for: window)
    }
    
    /// Returns the current size of the window
    var size: NSSize? {
        return accessibilityService.getSize(for: window)
    }
    
    /// Returns the current frame of the window
    var frame: NSRect? {
        guard let position = position, let size = size else { return nil }
        return NSRect(origin: position, size: size)
    }
    
    /// Whether the window is minimized
    var isMinimized: Bool {
        return accessibilityService.isMinimized(for: window)
    }
    
    /// Whether the window is in fullscreen mode
    var isFullscreen: Bool {
        return accessibilityService.isFullscreen(for: window)
    }
    
    // MARK: - Window Operations
    
    /// Moves the window to a new position
    /// - Parameter point: The new position
    func move(to point: NSPoint) {
        accessibilityService.setPosition(point, for: window)
    }
    
    /// Resizes the window
    /// - Parameter newSize: The new size
    func resize(to newSize: CGSize) {
        accessibilityService.setSize(newSize, for: window)
    }
    
    /// Sets both the position and size at once
    /// - Parameters:
    ///   - rect: The new frame
    ///   - animated: Whether to animate the change
    func setFrame(_ rect: NSRect, animated: Bool = false) {
        accessibilityService.setFrame(rect, for: window, animated: animated)
    }
    
    /// Brings the window to the front
    func focus() {
        accessibilityService.raiseWindow(window)
    }
    
    /// Toggles window minimized state
    func toggleMinimize() {
        accessibilityService.toggleMinimize(for: window)
    }
    
    /// Toggles window fullscreen state
    func toggleFullscreen() {
        accessibilityService.toggleFullscreen(for: window)
    }
    
    /// Disables the AXEnhancedUserInterface setting for this window
    func disableEnhancedUserInterface() {
        accessibilityService.disableEnhancedUserInterface(for: window)
    }
    
    /// Enables the AXEnhancedUserInterface setting for this window
    func enableEnhancedUserInterface() {
        accessibilityService.enableEnhancedUserInterface(for: window)
    }
    
    /// Perform an operation with enhanced user interface temporarily disabled
    func withEnhancedUserInterfaceDisabled<T>(_ operation: () -> T) -> T {
        return accessibilityService.withEnhancedUserInterfaceDisabled(for: window, operation)
    }
}
