//
//  TilingEngine.swift
//  Yuki
//
//  Created by Claude AI on 5/3/25.
//

import Foundation
import Cocoa

/// Split direction for Binary Space Partitioning
enum SplitDirection {
    case horizontal
    case vertical
}

/// Central engine for tiling operations
class TilingEngine {
    // MARK: - Properties
    
    /// Current tiling mode
    private(set) var currentMode: TilingMode = .default
    
    /// Spacing between windows
    private let spacing: CGFloat = 8.0
    
    /// Accessibility service for window operations
    private let accessibilityService = AccessibilityService.shared
    
    /// UserDefaults key for storing tiling mode
    private let tilingModeKey = "YukiTilingMode"
    
    // MARK: - Initialization
    
    init() {
        loadSavedMode()
    }
    
    // MARK: - Mode Management
    
    /// Set the current tiling mode
    func setMode(_ mode: TilingMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: tilingModeKey)
    }
    
    /// Cycle to the next tiling mode
    @discardableResult
    func cycleToNextMode() -> TilingMode {
        let nextMode = currentMode.next
        setMode(nextMode)
        return nextMode
    }
    
    /// Load tiling mode from user defaults or use default
    func loadSavedMode() {
        if let savedMode = UserDefaults.standard.string(forKey: tilingModeKey),
           let mode = TilingMode(rawValue: savedMode) {
            currentMode = mode
        } else {
            currentMode = .default
        }
    }
    
    // MARK: - Tiling Operations
    
    /// Apply the current tiling mode to a workspace
    func applyTiling(to workspace: Workspace, on monitor: Monitor) {
        // Skip tiling if in float mode
        if currentMode == .float {
            return
        }
        
        // Get all window nodes that should be tiled
        let windowNodes = workspace.root.getAllWindowNodes()
        
        // Skip if there are no windows to tile
        if windowNodes.isEmpty {
            return
        }
        
        // Get the available space for tiling
        let tilingArea = monitor.visibleFrame
        
        // Apply the appropriate tiling mode
        switch currentMode {
        case .bsp:
            applyBSPTiling(windowNodes, in: tilingArea)
        case .stack:
            applyStackTiling(windowNodes, in: tilingArea)
        case .float:
            // Nothing to do in float mode
            break
        }
    }
    
    // MARK: - BSP Tiling
    
    /// Apply Binary Space Partitioning tiling to windows
    private func applyBSPTiling(_ windowNodes: [WindowNode], in area: NSRect) {
        // If there's only one window, it gets the entire space
        if windowNodes.count == 1, let window = windowNodes.first {
            setWindowFrame(window, area)
            return
        }
        
        // If there are no windows, do nothing
        if windowNodes.isEmpty {
            return
        }
        
        // Recursive BSP layout
        applyBSPLayout(windowNodes, in: area, direction: .horizontal)
    }
    
    /// Recursive Binary Space Partitioning implementation
    private func applyBSPLayout(
        _ windowNodes: [WindowNode],
        in area: NSRect,
        direction: SplitDirection
    ) {
        // If there's only one window, it gets the entire space
        if windowNodes.count == 1, let window = windowNodes.first {
            setWindowFrame(window, area)
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
    
    /// Splits an area into two sub-areas based on the split direction
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
    
    // MARK: - Stack Tiling
    
    /// Apply stack tiling to windows (windows cover the entire screen and stack on top of each other)
    private func applyStackTiling(_ windowNodes: [WindowNode], in area: NSRect) {
        // Skip if there are no windows to tile
        if windowNodes.isEmpty {
            return
        }
        
        // In stack mode, all windows cover the entire monitor's visible area
        for window in windowNodes {
            setWindowFrame(window, area)
        }

        // Make sure the windows are properly stacked
        // The last window in the array should be on top
        for window in windowNodes.reversed() {
            accessibilityService.raiseWindow(window.window)
        }
    }
    
    // MARK: - Window Operations
    
    /// Set the frame of a window with proper error handling
    private func setWindowFrame(_ windowNode: WindowNode, _ frame: NSRect) {
        // Use the AccessibilityService to set the frame
        accessibilityService.setFrame(frame, for: windowNode.window, animated: false)
    }
}

// MARK: - Singleton for global access

extension TilingEngine {
    /// Shared instance
    static let shared = TilingEngine()
}

// MARK: - WindowManager Extension

extension WindowManager {
    /// Apply current tiling mode to the active workspace
    func applyCurrentTiling() {
        guard let workspace = selectedWorkspace,
              let monitor = monitors.first(where: { $0.workspaces.contains(where: { $0.id == workspace.id }) }) else {
            return
        }
        
        // Apply tiling using the TilingEngine
        TilingEngine.shared.applyTiling(to: workspace, on: monitor)
    }
    
    /// Cycle to the next tiling mode and apply it
    func cycleAndApplyNextTilingMode() {
        // Cycle to next mode
        let newMode = TilingEngine.shared.cycleToNextMode()
        
        // Apply the new tiling mode
        applyCurrentTiling()
        
        print("Switched to \(newMode.description) mode")
    }
}

// MARK: - Monitor Extension

extension Monitor {
    /// Apply current tiling mode to the active workspace
    func applyTilingToActiveWorkspace() {
        guard let workspace = activeWorkspace else {
            return
        }
        
        TilingEngine.shared.applyTiling(to: workspace, on: self)
    }
}
