//
//  TilingEngine+Classification.swift
//  Yuki
//
//  Created by Daniel Inama on 7/3/25.
//

import Foundation
import Cocoa

// MARK: - TilingEngine Extensions for Window Classification

extension TilingEngine {
    /// Apply tiling only to windows that should be tiled
    func applyTilingWithClassification() {
        guard let workspace = workspace else {
            print("Error: Workspace empty")
            return
        }
        let monitor = workspace.monitor

        // Get all visible, non-minimized windows
        let allVisibleWindows = workspace.getVisibleWindowNodes()
        
        // Classify windows into tiled and floating
        let (windowsToTile, windowsToFloat) = classifyWindows(allVisibleWindows)
        
        if windowsToTile.isEmpty && windowsToFloat.isEmpty {
            print("No visible windows to tile or float")
            return
        }
        
        print("Classified \(allVisibleWindows.count) windows: \(windowsToTile.count) to tile, \(windowsToFloat.count) to float")
        
        // Apply tiling only to windows that should be tiled
        if !windowsToTile.isEmpty {
            print("Applying \(strategy.name) strategy to \(windowsToTile.count) windows")
            strategy.applyLayout(to: windowsToTile, in: monitor.visibleFrame, with: config)
        }
        
        // Store classifications for later reference
        workspace.storeWindowClassifications(tiled: windowsToTile, floating: windowsToFloat)
    }
    
    /// Classify windows into tiled and floating groups
    private func classifyWindows(_ windows: [WindowNode]) -> (toTile: [WindowNode], toFloat: [WindowNode]) {
        let classifier = WindowClassifier.shared
        var windowsToTile: [WindowNode] = []
        var windowsToFloat: [WindowNode] = []
        
        for window in windows {
            if classifier.shouldWindowFloat(window.window) || window.isFloating {
                windowsToFloat.append(window)
            } else {
                windowsToTile.append(window)
            }
        }
        
        return (windowsToTile, windowsToFloat)
    }
}

// MARK: - WorkspaceNode Extensions for Window Classification

extension WorkspaceNode {
    // Property to store window classifications
    private struct StoredClassifications {
        var tiledWindows: [WindowNode]
        var floatingWindows: [WindowNode]
    }
    
    private struct AssociatedKeys {
        static var windowClassificationsKey = "com.yuki.windowClassificationsKey"
    }
    
    // Store window classifications for later reference
    func storeWindowClassifications(tiled: [WindowNode], floating: [WindowNode]) {
        let classifications = StoredClassifications(tiledWindows: tiled, floatingWindows: floating)
        objc_setAssociatedObject(self, &AssociatedKeys.windowClassificationsKey, classifications, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    // Get windows that were classified as tiled
    func getTiledWindows() -> [WindowNode] {
        if let stored = objc_getAssociatedObject(self, &AssociatedKeys.windowClassificationsKey) as? StoredClassifications {
            return stored.tiledWindows
        }
        return []
    }
    
    // Get windows that were classified as floating
    func getFloatingWindows() -> [WindowNode] {
        if let stored = objc_getAssociatedObject(self, &AssociatedKeys.windowClassificationsKey) as? StoredClassifications {
            return stored.floatingWindows
        }
        return []
    }
    
    // Apply tiling with classification
    func applyTilingWithClassification() {
        if let tilingEngine = self.tilingEngine {
            tilingEngine.applyTilingWithClassification()
        }
    }
}

// MARK: - WindowNode Extensions for Float State

extension WindowNode {
    // Associated object key for floating state
    private struct AssociatedKeys {
        static var isFloatingKey = "com.yuki.windowNode.isFloatingKey"
    }
    
    // Property to determine if this window should always float
    var isFloating: Bool {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.isFloatingKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isFloatingKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // Toggle floating state
    func toggleFloating() -> Bool {
        isFloating = !isFloating
        return isFloating
    }
}
