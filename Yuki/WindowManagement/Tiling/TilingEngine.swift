// BalancedTilingEngine.swift
// Balanced window classification that properly tiles main windows

import Cocoa
import Foundation

/// Central service for tiling operations
class TilingEngine {
    // MARK: - Properties
    
    /// Reference to the workspace this engine manages
    weak var workspace: WorkspaceNode?
    
    /// Current tiling strategy
    var strategy: TilingStrategy
    
    /// Configuration for tiling
    var config: TilingConfiguration
    
    // MARK: - Initialization
    
    /// Initialize with a workspace and optional strategy
    init(
        workspace: WorkspaceNode? = nil,
        initialStrategy: TilingStrategy = HStackStrategy()
    ) {
        self.workspace = workspace
        self.strategy = initialStrategy
        self.config = TilingConfiguration()
    }
    
    // MARK: - Tiling Operations
    
    /// Apply current tiling strategy to windows
    func applyTiling() {
       guard let workspace = workspace else {
            return
        }
        
        // Get all visible, non-minimized windows
        let allVisibleWindows = workspace.getVisibleWindowNodes()
        
        // Filter windows that should not be tiled
        let windowsToTile = allVisibleWindows.filter { !shouldWindowFloat($0) }
        
        // Debug information
//        print("\n===== WINDOW CLASSIFICATION =====")
//        print("Total windows: \(allVisibleWindows.count), Tiling: \(windowsToTile.count), Floating: \(allVisibleWindows.count - windowsToTile.count)")
//
//        for window in allVisibleWindows {
//            printWindowDetails(window, shouldFloat: !windowsToTile.contains(window))
//        }
//        print("=================================\n")
        
        // Only proceed if we have windows to tile
        if !windowsToTile.isEmpty {
            // Get the layouts but don't apply them directly
            strategy.applyLayout(to: windowsToTile, in: workspace.monitor.visibleFrame, with: config) { layouts in
                // Apply layouts in parallel
                WindowManager.shared.applyLayoutOperationsInParallel(layouts)
            }
        }
    }
    
    /// Change the tiling strategy
    func setStrategy(_ strategy: TilingStrategy) {
        self.strategy = strategy
        applyTiling()
    }
    
    /// Change the tiling mode by name
    func setTilingMode(_ modeName: String) {
        let strategy: TilingStrategy
        
        switch modeName.lowercased() {
            case "float":
                strategy = FloatStrategy()
            case "hstack":
                strategy = HStackStrategy()
            case "vstack":
                strategy = VStackStrategy()
            case "zstack":
                strategy = ZStackStrategy()
            case "bsp":
                strategy = BSPStrategy()
            default:
                strategy = BSPStrategy()
        }
        
        setStrategy(strategy)
    }
    
    /// Cycle to the next tiling mode
    @discardableResult
    func cycleToNextMode() -> TilingStrategy {
        let currentName = strategy.name
        
        let nextStrategy: TilingStrategy
        switch currentName {
            case "float":
                nextStrategy = HStackStrategy()
            case "hstack":
                nextStrategy = VStackStrategy()
            case "vstack":
                nextStrategy = ZStackStrategy()
            case "zstack":
                nextStrategy = BSPStrategy()
            case "bsp":
                nextStrategy = FloatStrategy()
            default:
                nextStrategy = BSPStrategy()
        }
        
        setStrategy(nextStrategy)
        return nextStrategy
    }
    
    /// Get current strategy name
    var currentModeName: String {
        return strategy.name
    }
    
    /// Get current strategy description
    var currentModeDescription: String {
        return strategy.description
    }
    
    
}
