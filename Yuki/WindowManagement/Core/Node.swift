// Node.swift
// Simplified node structure for window management

import Cocoa
import Foundation

/// Protocol for nodes in the window management tree
protocol Node: Identifiable, AnyObject, Hashable {
    var id: UUID { get }
    var title: String? { get set }
    var children: [any Node] { get set }
    var parent: (any Node)? { get set }
    
    func addChild(_ node: any Node)
    func removeChild(_ node: any Node)
}

/// Default implementations for Node protocol
extension Node {
    func addChild(_ node: any Node) {
        node.parent = self
        children.append(node)
    }
    
    func removeChild(_ node: any Node) {
        children.removeAll { $0.id == node.id }
    }
    
    func findNode(withID id: UUID) -> (any Node)? {
        if self.id == id {
            return self
        }
        
        for child in children {
            if let found = child.findNode(withID: id) {
                return found
            }
        }
        
        return nil
    }
}

/// WindowNode represents a single application window
class WindowNode: Node {
    
    static func == (lhs: WindowNode, rhs: WindowNode) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: UUID
    var title: String?
    var children: [any Node] = []
    weak var parent: (any Node)?
    
    /// The accessibility element for this window
    let window: AXUIElement
    
    /// The system window ID for faster lookups
    var systemWindowID: CGWindowID?
    
    /// Whether this window should always float
    var isFloating: Bool = false
    
    /// Whether this window is currently minimized
    var isMinimized: Bool = false
    
    // MARK: - Initialization
    
    init(window: AXUIElement) {
        self.id = UUID()
        self.window = window
        
        // Get the window title
        self.title = window.get(Ax.titleAttr)
        
        // Get the system window ID
        var windowID: CGWindowID = 0
        if _AXUIElementGetWindow(window, &windowID) == .success {
            self.systemWindowID = windowID
        }
        
        // Check initial minimized state
        self.isMinimized = window.get(Ax.minimizedAttr) ?? false
    }
    
    // MARK: - Window Properties
    
    /// Get the current position of the window
    var position: NSPoint? {
        return window.get(Ax.topLeftCornerAttr)
    }
    
    /// Get the current size of the window
    var size: NSSize? {
        return window.get(Ax.sizeAttr)
    }
    
    /// Get the current frame of the window
    var frame: NSRect? {
        guard let position = position, let size = size else { return nil }
        return NSRect(origin: position, size: size)
    }
    
    // MARK: - Window Operations
    
    /// Move the window to a new position
    func move(to point: NSPoint) {
        // Skip if minimized
        if isMinimized { return }
        window.set(Ax.topLeftCornerAttr, point)
    }
    
    /// Resize the window
    func resize(to newSize: CGSize) {
        // Skip if minimized
        if isMinimized { return }
        window.set(Ax.sizeAttr, newSize)
    }
    
    /// Set both position and size at once
    func setFrame(_ rect: NSRect) {
        // Skip if minimized
        if isMinimized { return }
        
        // Disable enhanced user interface temporarily for smoother operation
        let enhancedUI = window.isEnhancedUserInterfaceEnabled()
        if enhancedUI == true {
            window.disableEnhancedUserInterface()
        }
        
        // Set size first, then position for better visual results
        window.set(Ax.sizeAttr, rect.size)
        window.set(Ax.topLeftCornerAttr, rect.origin)
        
        // Restore enhanced UI if it was enabled
        if enhancedUI == true {
            window.enableEnhancedUserInterface()
        }
    }
    
    /// Focus this window
    func focus() {
        if isMinimized {
            // Unminimize the window first
            window.set(Ax.minimizedAttr, false)
            isMinimized = false
        }
        
        window.raise()
    }
    
    /// Toggle minimize state
    func toggleMinimize() {
        let minimized = window.get(Ax.minimizedAttr) ?? false
        window.set(Ax.minimizedAttr, !minimized)
        isMinimized = !minimized
    }
    
    /// Toggle fullscreen state
    func toggleFullscreen() {
        let fullscreen = window.get(Ax.isFullscreenAttr) ?? false
        window.set(Ax.isFullscreenAttr, !fullscreen)
    }
    
    /// Toggle floating state
    @discardableResult
    func toggleFloating() -> Bool {
        isFloating = !isFloating
        return isFloating
    }
}

