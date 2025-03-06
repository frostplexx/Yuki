//
//  RootNode.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Foundation

class RootNode: Node {
    var type: NodeType

    var children: [any Node] = []

    var parent: (any Node)?

    var id: UUID

    var title: String?

    
    init(){
        self.type = .rootNode
        self.id = UUID()
        self.title = "ROOT"
    }
}
