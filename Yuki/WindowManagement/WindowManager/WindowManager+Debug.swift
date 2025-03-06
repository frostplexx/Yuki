//
//  WindowManager+Debug.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Foundation


extension WindowManager {
    func printDebugInfo() {
        print("Monitor with mouse: \(monitorWithMouse?.name ?? "(Untitled)")")
        for monitor in monitors {
            print("== \(monitor.name) ==")
            print("Active Workspace: \(monitor.activeWorkspace?.title ?? "(Untitled)")")
            for workspace in monitor.workspaces {
                print("- Workspace: \(workspace.title ?? "(Untitled)")")
                recursivePrintNodes(of: workspace)
            }
        }
    }
    
    private func recursivePrintNodes(of node: any Node, indent: String = "  ") {
        for (index, child) in node.children.enumerated() {
            let isLast = index == node.children.count - 1
            let prefix = isLast ? "└─ " : "├─ "
            let childIndent = isLast ? "   " : "│  "
            
            // Print the current node with appropriate type information
            let typeStr: String
            switch child.type {
            case .container:
                typeStr = "Container"
            case .window:
                typeStr = "Window"
            case .workspace:
                typeStr = "Workspace"
            case .rootNode:
                typeStr = "Root"
            }
            
            print("\(indent)\(prefix)\(typeStr): \(child.title ?? "(Untitled)") [\(child.id)]")
            
            // Recursively print children with increased indentation
            recursivePrintNodes(of: child, indent: indent + childIndent)
        }
    }
}
