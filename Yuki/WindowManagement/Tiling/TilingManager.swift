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
    var currentMode: TilingMode = TilingMode.default
    
    /// Spacing between windows
    let spacing: CGFloat = 8.0
    
    
    var tilingTimer: Timer?
    
    /// The window manager instance
//    weak var windowManager: WindowManager?

    // MARK: - Initialization
    
    private init() {
//        self.windowManager = WindowManagerProvider.shared
        setupNotifications()
    }
    
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
    
}

// MARK: - Split Direction Enum

/// Direction for splitting in BSP tiling
enum SplitDirection {
    case horizontal
    case vertical
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
