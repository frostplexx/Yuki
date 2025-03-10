// TilingConfiguration.swift
// Configuration for tiling operations

import Foundation

/// Configuration for tiling operations
struct TilingConfiguration {
    /// Spacing between windows
    var windowGap: CGFloat = 8.0
    
    /// Margin around workspace edge
    var outerGap: CGFloat = 8.0
    
    /// Whether to restore window positions when switching workspaces
    var restorePositions: Bool = true
    
    /// Whether to automatically tile new windows
    var autoTileNewWindows: Bool = true
    
    /// Whether to show visual feedback during tiling operations
    var showTilingAnimation: Bool = true
    
    /// Default initialization
    init(
        windowGap: CGFloat = 8.0,
        outerGap: CGFloat = 8.0,
        restorePositions: Bool = true,
        autoTileNewWindows: Bool = true,
        showTilingAnimation: Bool = true
    ) {
        self.windowGap = windowGap
        self.outerGap = outerGap
        self.restorePositions = restorePositions
        self.autoTileNewWindows = autoTileNewWindows
        self.showTilingAnimation = showTilingAnimation
    }
}
