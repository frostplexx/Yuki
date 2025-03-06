//
//  ContainerNode.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Foundation

/// Represents a container that can hold multiple windows or other containers
class ContainerNode: Node {

    var type: NodeType
    var children: [any Node] = []
    var parent: (any Node)?
    let id: UUID
    var title: String?

    /// Spacing between child elements
    var spacing: CGFloat = 8.0

    /// Whether to distribute child elements evenly
    var distributeEvenly: Bool = true

    init(id: UUID = UUID(), title: String? = nil) {
        self.type = .container
        self.id = id
        self.title = title
    }
}
