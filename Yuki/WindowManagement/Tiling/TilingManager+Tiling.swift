//
//  TilingManager+Tiling.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Foundation

extension TilingManager {
    
    // MARK: - Tiling Operations
    
    /// Apply the current tiling mode to a workspace
    /// - Parameters:
    ///   - workspace: The workspace to tile
    ///   - monitor: The monitor containing the workspace
    func applyTiling(to workspace: Workspace, on monitor: Monitor) {
        // Skip tiling if in float mode
        if currentMode == .float {
            print("Floating mode - no automatic tiling applied")
            return
        }
        
        // Clean up workspace structure first
        workspace.cleanupStructure()
        
        // Apply the appropriate tiling mode
        switch currentMode {
        case .bsp:
            applyBSPTiling(to: workspace, on: monitor)
        case .stack:
            applyStackTiling(to: workspace, on: monitor)
        case .float:
            // Nothing to do in float mode
            break
        }
    }
    
    /// Apply Binary Space Partitioning tiling to a workspace
    /// - Parameters:
    ///   - workspace: The workspace to tile
    ///   - monitor: The monitor containing the workspace
    private func applyBSPTiling(to workspace: Workspace, on monitor: Monitor) {
        // Get all window nodes that should be tiled
        let windowNodes = workspace.root.getAllWindowNodes()
        
        // Skip if there are no windows to tile
        if windowNodes.isEmpty {
            return
        }
        
        // Get the available space for tiling
        let tilingArea = monitor.visibleFrame
        
        // Apply recursive BSP layout
        applyBSPLayout(windowNodes, in: tilingArea, direction: .horizontal)
        
        print("Applied BSP tiling to \(windowNodes.count) windows in workspace '\(workspace.name)'")
    }
    
    /// Recursive Binary Space Partitioning implementation
    /// - Parameters:
    ///   - windowNodes: Windows to tile
    ///   - area: Area to tile within
    ///   - direction: Current split direction
    private func applyBSPLayout(
        _ windowNodes: [WindowNode],
        in area: NSRect,
        direction: SplitDirection
    ) {
        // If there's only one window, it gets the entire space
        if windowNodes.count == 1, let window = windowNodes.first {
            window.setFrame(area)
            return
        }
        
        // If there are no windows, do nothing
        if windowNodes.isEmpty {
            return
        }
        
        // Split the windows into two groups
        let midIndex = windowNodes.count / 2
        let firstGroup = Array(windowNodes[0..<midIndex])
        let secondGroup = Array(windowNodes[midIndex...])
        
        // Calculate the two sub-areas based on the split direction
        let (firstArea, secondArea) = splitArea(area, direction: direction)
        
        // Recursively apply BSP to each group and sub-area with alternating direction
        let nextDirection: SplitDirection = direction == .horizontal ? .vertical : .horizontal
        applyBSPLayout(firstGroup, in: firstArea, direction: nextDirection)
        applyBSPLayout(secondGroup, in: secondArea, direction: nextDirection)
    }
    
    /// Apply stack tiling to a workspace (windows cover the entire screen and stack on top of each other)
    /// - Parameters:
    ///   - workspace: The workspace to tile
    ///   - monitor: The monitor containing the workspace
    private func applyStackTiling(to workspace: Workspace, on monitor: Monitor) {
        // Get all window nodes to tile
        let windowNodes = workspace.root.getAllWindowNodes()
        
        // Skip if there are no windows to tile
        if windowNodes.isEmpty {
            return
        }
        
        // In stack mode, all windows cover the entire monitor's visible area
        let tilingArea = monitor.visibleFrame
        
        // Apply the same frame to all windows
        for window in windowNodes {
            window.setFrame(tilingArea)
        }
        
        // Make sure the most recently active window is on top
        // This is usually handled by the window manager automatically
        // when a window gets focus
        
        print("Applied stack tiling to \(windowNodes.count) windows in workspace '\(workspace.name)'")
    }
    
    /// Splits an area into two sub-areas based on the split direction
    /// - Parameters:
    ///   - area: The area to split
    ///   - direction: The direction to split in
    /// - Returns: Two sub-areas
    private func splitArea(_ area: NSRect, direction: SplitDirection) -> (NSRect, NSRect) {
        switch direction {
        case .horizontal:
            // Split horizontally (side by side)
            let leftWidth = (area.width - spacing) / 2
            let rightWidth = area.width - leftWidth - spacing
            
            let leftArea = NSRect(
                x: area.minX,
                y: area.minY,
                width: leftWidth,
                height: area.height
            )
            
            let rightArea = NSRect(
                x: area.minX + leftWidth + spacing,
                y: area.minY,
                width: rightWidth,
                height: area.height
            )
            
            return (leftArea, rightArea)
            
        case .vertical:
            // Split vertically (top and bottom)
            let topHeight = (area.height - spacing) / 2
            let bottomHeight = area.height - topHeight - spacing
            
            let topArea = NSRect(
                x: area.minX,
                y: area.minY + bottomHeight + spacing,
                width: area.width,
                height: topHeight
            )
            
            let bottomArea = NSRect(
                x: area.minX,
                y: area.minY,
                width: area.width,
                height: bottomHeight
            )
            
            return (topArea, bottomArea)
        }
    }
}

