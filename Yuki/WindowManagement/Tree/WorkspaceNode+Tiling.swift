//
//  WorkspaceNode+Tiling.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import AppKit
import Foundation

// MARK: - Tiling Extensions for WorkspaceNode

extension WorkspaceNode {

    /// Window positions to enforce when tiling is active
    var tiledWindowPositions: [Int: NSRect] {
        get {
            if let stored = objc_getAssociatedObject(
                self, &AssociatedKeys.tiledWindowPositionsKey) as? [Int: NSRect]
            {
                return stored
            }
            let newValue = [Int: NSRect]()
            objc_setAssociatedObject(
                self, &AssociatedKeys.tiledWindowPositionsKey, newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return newValue
        }
        set {
            objc_setAssociatedObject(
                self, &AssociatedKeys.tiledWindowPositionsKey, newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // Keys for associated objects
    private struct AssociatedKeys {
        static var tiledWindowPositionsKey = "com.yuki.tiledWindowPositionsKey"
        static var isObservingKey = "com.yuki.isObservingKey"
    }
    

    // MARK: - Observation Setup

    /// Setup observation for window events - no longer registers individual listeners
    func setupObservation() {
        // Mark as observing to avoid repeated setup
        objc_setAssociatedObject(
            self, &AssociatedKeys.isObservingKey, true,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
//        print("WorkspaceNode \(title ?? "unknown") is ready for window events")
    }

    /// Check if a window belongs to this workspace
    func windowBelongsToThisWorkspace(_ windowId: Int) -> Bool {
        if let workspaceId = WindowManager.shared.windowOwnership[windowId] {
            return workspaceId == id
        }
        return false
    }

    /// Reapply tiling with a short delay
    func reapplyTilingWithDelay() {
        needsReapplyTiling = true
        
        // If timer already exists, just let it fire
        if reapplyTilingTimer != nil {
            return
        }
        
        // Create a new timer that will check the flag
        reapplyTilingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            guard let self = self, self.needsReapplyTiling else { return }
            
            self.needsReapplyTiling = false
            self.reapplyTilingTimer = nil
            
            DispatchQueue.global(qos: .userInteractive).async {
                // Do calculations off main thread
                // Then apply on main thread:
                DispatchQueue.main.async {
                    self.applyTiling()
                    self.captureWindowPositions()
                }
            }
        }
    }

    // MARK: - Tiling Management

    /// Store current window positions for enforcement
    func captureWindowPositions() {
        // Clear existing positions
        var positions = [Int: NSRect]()

        // Get all windows in the workspace
        let windows = getAllWindowNodes()

        // Store their current positions
        for window in windows {
            if let windowId = Int(window.systemWindowID ?? "0"),
                let frame = window.frame
            {
                positions[windowId] = frame
            }
        }

        // Update stored positions
        tiledWindowPositions = positions
    }
    
    /// Apply current tiling strategy to this workspace
    func applyTiling() {
        // If it's the float mode, don't apply tiling
        if tilingEngine?.currentModeName == "float" {
            return
        }

        tilingEngine?.applyTiling()

        // Capture window positions after applying tiling
        captureWindowPositions()
    }

    /// Set tiling strategy for this workspace
    func setTilingStrategy(_ strategy: TilingStrategy) {
        tilingEngine?.setStrategy(strategy)

        // Apply immediately
        applyTiling()

        // Notify that tiling mode has changed
        WindowObserverService.shared.postTilingModeChanged(self)
    }

    /// Set tiling mode by name
    func setTilingMode(_ modeName: String) {
        tilingEngine?.setTilingMode(modeName)

        // Apply immediately
        applyTiling()

        // Notify that tiling mode has changed
        WindowObserverService.shared.postTilingModeChanged(self)
    }

    /// Cycle to next tiling mode
    @discardableResult
    func cycleToNextTilingMode() -> TilingStrategy? {
        guard let strategy = tilingEngine?.cycleToNextMode() else { return nil }

        // Apply immediately
        applyTiling()

        // Notify that tiling mode has changed
        WindowObserverService.shared.postTilingModeChanged(self)

        return strategy
    }

    /// Update tiling configuration
    func setTilingConfiguration(_ config: TilingConfiguration) {
        tilingEngine?.config = config
        applyTiling()
    }
}
