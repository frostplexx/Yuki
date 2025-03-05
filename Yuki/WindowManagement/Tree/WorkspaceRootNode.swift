//
//  WorkspaceRootNode.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Foundation

/// Root node for a workspace
class WorkspaceRootNode: Node {

    var type: NodeType { .rootNode }
    var children: [any Node] = []
    var parent: (any Node)? = nil
    let id: UUID = UUID()
    var title: String?

    init(title: String? = "Root") {
        self.title = title
    }

    /// Finds a window node by system window ID
    /// - Parameter systemWindowID: The system window ID to find
    /// - Returns: The window node if found, nil otherwise
    func findWindowNode(systemWindowID: Int) -> WindowNode? {
        // Check direct children
        for child in children {
            if let windowNode = child as? WindowNode,
                windowNode.systemWindowID == systemWindowID
            {
                return windowNode
            }
        }

        // Check container children
        for child in children {
            if let container = child as? ContainerNode {
                for subChild in container.children {
                    if let windowNode = subChild as? WindowNode,
                        windowNode.systemWindowID == systemWindowID
                    {
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
