//
//  Node.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Cocoa
import CoreFoundation
import Foundation

// MARK: - Node Types

/// Types of nodes in the window tree
/// Types of nodes in the window tree
enum NodeType {
    case rootNode
    case workspace
    case container
    case window
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
            let nodeChild = ($0 as (any Node))
            return nodeChild.id == child.id
        }
    }
}


