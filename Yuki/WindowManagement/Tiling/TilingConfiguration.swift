//
//  TilingConfiguration.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

/// Configuration for tiling operations
struct TilingConfiguration {
    // MARK: - Properties
    
    /// Spacing between windows
    var windowGap: CGFloat = 8.0
    
    /// Margin around workspace edge
    var outerGap: CGFloat = 8.0
    
    /// Whether windows should be resizable
    var allowResize: Bool = false
    
    /// Whether windows should be movable
    var allowMove: Bool = false
    
    /// Whether to restore window positions when switching workspaces
    var restorePositions: Bool = true
    
    // MARK: - Initialization
    
    /// Default initializer
    init(
        windowGap: CGFloat = 8.0,
        outerGap: CGFloat = 8.0,
        allowResize: Bool = false,
        allowMove: Bool = false,
        restorePositions: Bool = true
    ) {
        self.windowGap = windowGap
        self.outerGap = outerGap
        self.allowResize = allowResize
        self.allowMove = allowMove
        self.restorePositions = restorePositions
    }
}
