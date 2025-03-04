//
//  TilingManager.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa

// MARK: - Tiling Manager

/// Class responsible for handling window tiling operations
class TilingManager {
    /// Singleton instance
    static let shared = TilingManager()
    
    /// Current tiling mode
    private var currentMode: TilingMode = TilingMode.default
    
    /// Spacing between windows
    private let spacing: CGFloat = 8.0
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Mode Management
    
    /// Get the current tiling mode
    /// - Returns: The current tiling mode
    func getCurrentMode() -> TilingMode {
        return currentMode
    }
    
    /// Set the current tiling mode
    /// - Parameter mode: The new tiling mode
    func setMode(_ mode: TilingMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "YukiTilingMode")
    }
    
    /// Cycle to the next tiling mode
    /// - Returns: The new tiling mode
    @discardableResult
    func cycleToNextMode() -> TilingMode {
        let nextMode = currentMode.next
        setMode(nextMode)
        return nextMode
    }
    
    /// Load tiling mode from user defaults or use default
    func loadSavedMode() {
        if let savedMode = UserDefaults.standard.string(forKey: "YukiTilingMode"),
           let mode = TilingMode(rawValue: savedMode) {
            currentMode = mode
        } else {
            currentMode = .bsp
        }
    }
    
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

// MARK: - Split Direction Enum

/// Direction for splitting in BSP tiling
enum SplitDirection {
    case horizontal
    case vertical
}

// MARK: - WindowNode Extension

extension WindowNode {
    /// Sets the position and size of the window
    /// - Parameter rect: The rectangle to position and size the window
    func setFrame(_ rect: NSRect) {
        let app = AXUIElementCreateApplication(window.pid())
        
        // Check if enhanced user interface is enabled
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, "AXEnhancedUserInterface" as CFString, &value)
        let wasEnabled = (result == .success && (value as? Bool) == true)
        
        // Disable enhanced user interface if it was enabled
        if wasEnabled {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, false as CFTypeRef)
        }
        
        // Resize and reposition
        resize(to: CGSize(width: rect.width, height: rect.height))
        move(to: NSPoint(x: rect.minX, y: rect.minY))
        
        // Restore the previous state
        if wasEnabled {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
        }
    }
}

// MARK: - Workspace Extension

extension Workspace {
    /// Clean up the workspace structure
    func cleanupStructure() {
        // Handle any duplicate containers
        let hstackContainers = root.children.compactMap {
            $0 as? ContainerNode
        }.filter {
            $0.type == .hStack
        }
        
        // If we have more than one HStack container, merge them
        if hstackContainers.count > 1 {
            // Keep the first container
            let primaryContainer = hstackContainers[0]
            
            // Move all windows from other containers to the first one
            for container in hstackContainers.dropFirst() {
                for child in container.children {
                    if let windowNode = child as? WindowNode {
                        // Remove from current container
                        var mutableContainer = container
                        mutableContainer.remove(windowNode)
                        
                        // Add to primary container
                        var mutablePrimaryContainer = primaryContainer
                        mutablePrimaryContainer.append(windowNode)
                    }
                }
                
                // Remove the empty container
                var mutableRoot = root
                mutableRoot.remove(container)
            }
        }
        
        // Move any direct window children to an HStack container
        let directWindowNodes = root.children.compactMap { $0 as? WindowNode }
        
        if !directWindowNodes.isEmpty {
            let container: ContainerNode
            
            // Use existing HStack container or create a new one
            if let existingContainer = hstackContainers.first {
                container = existingContainer
            } else {
                container = ContainerNode(type: .hStack, title: "Default Layout")
                var mutableRoot = root
                mutableRoot.append(container)
            }
            
            // Move direct windows to the container
            for windowNode in directWindowNodes {
                var mutableRoot = root
                mutableRoot.remove(windowNode)
                
                var mutableContainer = container
                mutableContainer.append(windowNode)
            }
        }
    }
}

// MARK: - WindowManager Extensions

extension WindowManager {
    /// Apply current tiling mode to the active workspace
    func applyCurrentTiling() {
        guard let workspace = selectedWorkspace,
              let monitor = monitors.first(where: { $0.workspaces.contains(where: { $0.id == workspace.id }) }) else {
            return
        }
        
        // Apply tiling using the TilingManager
        TilingManager.shared.applyTiling(to: workspace, on: monitor)
    }
    
    /// Cycle to the next tiling mode and apply it
    func cycleAndApplyNextTilingMode() {
        // Cycle to next mode
        let newMode = TilingManager.shared.cycleToNextMode()
        
        // Apply the new tiling mode
        applyCurrentTiling()
        
        print("Switched to \(newMode.description) mode")
    }
    
    /// Initialize tiling when app starts
    func initializeTiling() {
        // Load saved tiling mode
        TilingManager.shared.loadSavedMode()
        
        // Apply tiling to all workspaces
        for monitor in monitors {
            for workspace in monitor.workspaces {
                TilingManager.shared.applyTiling(to: workspace, on: monitor)
            }
        }
    }
}

// MARK: - Monitor Extension

extension Monitor {
    /// Apply current tiling mode to the active workspace
    func applyTilingToActiveWorkspace() {
        guard let workspace = activeWorkspace else {
            return
        }
        
        TilingManager.shared.applyTiling(to: workspace, on: self)
    }
}
