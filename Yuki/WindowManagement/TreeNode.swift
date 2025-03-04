//
//  Node.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import CoreFoundation
import Cocoa

// MARK: - Node Types

/// Types of nodes in the window tree
enum NodeType {
    case rootNode
    case window
    case vStack
    case hStack
    case zStack
}

// MARK: - Node Protocol

/// Base protocol for all nodes in the window tree
protocol Node: Hashable, Identifiable {
    var type: NodeType { get }
    var children: [any Node] { get set }
    var parent: (any Node)? { get set }
    var id: UUID { get }
    var title: String? { get set }
    
    mutating func append(_ child: any Node)
    mutating func prepend(_ child: any Node)
    mutating func remove(_ child: any Node)
}

// MARK: - Node Default Implementations

extension Node {
    /// Convenience property to check if this is a window node
    var isWindow: Bool {
        type == .window
    }
    
    /// Equatable implementation
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Append a child node (mutable version)
    mutating func append(_ child: inout any Node) {
        child.parent = self
        children.append(child)
    }
    
    /// Append a child node
    mutating func append(_ child: any Node) {
        var mutableChild = child
        mutableChild.parent = self
        children.append(mutableChild)
    }
    
    /// Prepend a child node
    mutating func prepend(_ child: any Node) {
        var mutableChild = child
        mutableChild.parent = self
        children.insert(mutableChild, at: 0)
    }
    
    /// Remove a child node
    mutating func remove(_ child: any Node) {
        children.removeAll {
            if let nodeChild = $0 as? (any Node) {
                return nodeChild.id == child.id
            }
            return false
        }
    }
}

// MARK: - WindowNode Implementation

/// Represents a window in the window tree
class WindowNode: Node {
    // MARK: Node Protocol Properties
    
    var title: String?
    var type: NodeType { .window }
    var children: [any Node] = []
    var parent: (any Node)?
    let id: UUID
    
    // MARK: Window-Specific Properties
    
    /// The accessibility element for this window
    let window: AXUIElement
    
    /// The system window ID from CGWindowID (optional)
    var systemWindowID: Int?
    
    // MARK: Initialization
    
    /// Initialize with an accessibility element
    init(_ window: AXUIElement) {
        self.id = UUID()
        self.window = window
        self.title = window.get(Ax.titleAttr)
//        self.systemWindowID = window.get(Ax.identifierAttr)
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
}

// MARK: - ContainerNode Implementation

/// Represents a container that can hold multiple windows or other containers
class ContainerNode: Node {
    // MARK: Node Protocol Properties
    
    var type: NodeType
    var children: [any Node] = []
    var parent: (any Node)?
    let id: UUID
    var title: String?
    
    // MARK: Container-Specific Properties
    
    /// Spacing between child elements
    var spacing: CGFloat = 8.0
    
    /// Whether to distribute child elements evenly
    var distributeEvenly: Bool = true
    
    // MARK: Initialization
    
    init(type: NodeType = .hStack, id: UUID = UUID(), title: String? = nil) {
        self.type = type
        self.id = id
        self.title = title
    }
    
    // MARK: Layout Methods
    
    /// Calculates the layout for all children based on the container type
    /// - Parameters:
    ///   - frame: The frame to layout within
    ///   - force: Whether to apply the layout immediately
    func calculateLayout(in frame: NSRect, force: Bool = false) {
        guard !children.isEmpty else { return }
        
        // Skip if there are no window children
        let windowNodes = children.compactMap { $0 as? WindowNode }
        guard !windowNodes.isEmpty else { return }
        
        switch type {
        case .hStack:
            layoutHorizontally(windowNodes, in: frame, force: force)
        case .vStack:
            layoutVertically(windowNodes, in: frame, force: force)
        case .zStack:
            layoutStacked(windowNodes, in: frame, force: force)
        default:
            // For other container types, don't apply automatic layout
            break
        }
    }
    
    /// Layouts children horizontally (side by side)
    private func layoutHorizontally(_ windows: [WindowNode], in frame: NSRect, force: Bool) {
        let count = windows.count
        let totalWidth = frame.width
        let itemWidth = distributeEvenly ? (totalWidth - spacing * CGFloat(count - 1)) / CGFloat(count) : 0
        
        for (index, window) in windows.enumerated() {
            let x = frame.minX + CGFloat(index) * (itemWidth + spacing)
            let windowFrame = NSRect(
                x: x,
                y: frame.minY,
                width: itemWidth,
                height: frame.height
            )
            
            if force {
                window.move(to: NSPoint(x: windowFrame.minX, y: windowFrame.minY))
                window.resize(to: CGSize(width: windowFrame.width, height: windowFrame.height))
            }
        }
    }
    
    /// Layouts children vertically (stacked top to bottom)
    private func layoutVertically(_ windows: [WindowNode], in frame: NSRect, force: Bool) {
        let count = windows.count
        let totalHeight = frame.height
        let itemHeight = distributeEvenly ? (totalHeight - spacing * CGFloat(count - 1)) / CGFloat(count) : 0
        
        for (index, window) in windows.enumerated() {
            let y = frame.maxY - CGFloat(index + 1) * (itemHeight + spacing) + spacing
            let windowFrame = NSRect(
                x: frame.minX,
                y: y,
                width: frame.width,
                height: itemHeight
            )
            
            if force {
                window.move(to: NSPoint(x: windowFrame.minX, y: windowFrame.minY))
                window.resize(to: CGSize(width: windowFrame.width, height: windowFrame.height))
            }
        }
    }
    
    /// Layouts children stacked (all in the same space)
    private func layoutStacked(_ windows: [WindowNode], in frame: NSRect, force: Bool) {
        for window in windows {
            if force {
                window.move(to: NSPoint(x: frame.minX, y: frame.minY))
                window.resize(to: CGSize(width: frame.width, height: frame.height))
            }
        }
    }
}

// MARK: - WorkspaceRootNode Implementation

/// Root node for a workspace
class WorkspaceRootNode: Node {
    // MARK: Node Protocol Properties
    
    var type: NodeType { .rootNode }
    var children: [any Node] = []
    var parent: (any Node)? = nil
    let id: UUID = UUID()
    var title: String?
    
    // MARK: Initialization
    
    init(title: String? = "Root") {
        self.title = title
    }
}

