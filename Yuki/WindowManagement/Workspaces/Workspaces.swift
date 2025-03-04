//
//  Workspace.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa

// MARK: - Workspace Class

/// Represents a workspace with a root node and metadata
class Workspace: Identifiable, Hashable, ObservableObject {
    /// Unique identifier
    let id: UUID
    
    /// Workspace name
    @Published var name: String
    
    /// The root node of the workspace
    let root = WorkspaceRootNode()
    
    /// Monitor this workspace belongs to (weak reference to avoid cycles)
    weak var monitor: Monitor?
    
    /// Cache for the default container
    var _defaultContainer: ContainerNode?
    
    /// Display name (including window count)
    var displayName: String {
        let windowCount = root.getAllWindowNodes().count
        return "\(name) (\(windowCount) windows)"
    }
    
    /// Initialize a new workspace
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new random UUID)
    ///   - name: Workspace name
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        
        // Ensure we have the proper structure
        initializeDefaultStructure()
    }
    
    // MARK: - Default Container
    
    /// Returns the default HStack container for this workspace
    var defaultContainer: ContainerNode {
        // Return cached container if available
        if let container = _defaultContainer {
            return container
        }
        
        // Look for an existing HStack container
        for child in root.children {
            if let container = child as? ContainerNode, container.type == .hStack {
                _defaultContainer = container
                return container
            }
        }
        
        // Create a new HStack container if one doesn't exist
        let container = ContainerNode(type: .hStack, title: "Default Layout")
        var mutableRoot = root
        mutableRoot.append(container)
        
        // Cache the container
        _defaultContainer = container
        
        return container
    }
    
    /// Initialize workspace structure with default container
    func initializeDefaultStructure() {
        // Check if we already have a default HStack container
        let existingHStack = root.children.contains { child in
            if let container = child as? ContainerNode, container.type == .hStack {
                return true
            }
            return false
        }
        
        // If we don't have an HStack container, create one
        if !existingHStack {
            let container = ContainerNode(type: .hStack, title: "Default Layout")
            var mutableRoot = root
            mutableRoot.append(container)
            _defaultContainer = container
        }
    }
    
    // MARK: - Window Management
    
    /// Adds a window to the default container
    /// - Parameter windowNode: The window node to add
    func addWindowToDefaultContainer(_ windowNode: WindowNode) {
        var container = defaultContainer
        container.append(windowNode)
    }
    
    /// Find a window node by its system window ID
    /// - Parameter systemWindowID: The system window ID to look for
    /// - Returns: The window node, or nil if not found
    func findWindowNode(systemWindowID: Int) -> WindowNode? {
        return root.findWindowNode(systemWindowID: systemWindowID)
    }
    
    // MARK: - Equatable & Hashable
    
    static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - WorkspaceRootNode Extension

extension WorkspaceRootNode {
    /// Finds a window node by system window ID
    /// - Parameter systemWindowID: The system window ID to find
    /// - Returns: The window node if found, nil otherwise
    func findWindowNode(systemWindowID: Int) -> WindowNode? {
        // Check direct children
        for child in children {
            if let windowNode = child as? WindowNode, windowNode.systemWindowID == systemWindowID {
                return windowNode
            }
        }
        
        // Check container children
        for child in children {
            if let container = child as? ContainerNode {
                for subChild in container.children {
                    if let windowNode = subChild as? WindowNode, windowNode.systemWindowID == systemWindowID {
                        return windowNode
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Gets all window nodes in the workspace
    /// - Returns: Array of all window nodes
    func getAllWindowNodes() -> [WindowNode] {
        var result: [WindowNode] = []
        
        // Check direct children
        for child in children {
            if let windowNode = child as? WindowNode {
                result.append(windowNode)
            }
        }
        
        // Check container children
        for child in children {
            if let container = child as? ContainerNode {
                for subChild in container.children {
                    if let windowNode = subChild as? WindowNode {
                        result.append(windowNode)
                    }
                }
            }
        }
        
        return result
    }
}
