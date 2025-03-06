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

    /// Setup observation for window events
    func setupObservation() {
        // Check if already observing
        if objc_getAssociatedObject(self, &AssociatedKeys.isObservingKey)
            as? Bool == true
        {
            return
        }

        // Mark as observing
        objc_setAssociatedObject(
            self, &AssociatedKeys.isObservingKey, true,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let nc = WindowNotificationCenter.shared

        // Listen for window moved notifications
        nc.addObserver(
            self,
            selector: #selector(handleWindowMoved(_:)),
            name: .windowMoved
        )

        // Listen for window resized notifications
        nc.addObserver(
            self,
            selector: #selector(handleWindowResized(_:)),
            name: .windowResized
        )

        // Listen for window created notifications
        nc.addObserver(
            self,
            selector: #selector(handleWindowCreated(_:)),
            name: .windowCreated
        )

        // Listen for window removed notifications
        nc.addObserver(
            self,
            selector: #selector(handleWindowRemoved(_:)),
            name: .windowRemoved
        )

        print(
            "WorkspaceNode \(title ?? "unknown") is now observing window events"
        )
    }

    // MARK: - Event Handlers

    @objc func handleWindowMoved(_ notification: Notification) {
        guard isActive,
            let windowId = notification.userInfo?["windowId"] as? Int,
            windowBelongsToThisWorkspace(windowId)
        else {
            return
        }

        print("Window \(windowId) moved in workspace \(title ?? "unknown")")
        reapplyTilingWithDelay()
    }

    @objc func handleWindowResized(_ notification: Notification) {
        guard isActive,
            let windowId = notification.userInfo?["windowId"] as? Int,
            windowBelongsToThisWorkspace(windowId)
        else {
            return
        }

        print("Window \(windowId) resized in workspace \(title ?? "unknown")")
        reapplyTilingWithDelay()
    }

    @objc func handleWindowCreated(_ notification: Notification) {
        guard isActive,
            let windowId = notification.userInfo?["windowId"] as? Int
        else {
            return
        }

        // Apply tiling if this window belongs to this workspace
        if windowBelongsToThisWorkspace(windowId) {
            print(
                "Window \(windowId) created in workspace \(title ?? "unknown")")
            reapplyTilingWithDelay()
        }
    }

    @objc func handleWindowRemoved(_ notification: Notification) {
        guard isActive,
            let windowId = notification.userInfo?["windowId"] as? Int
        else {
            return
        }

        // Apply tiling if this window belonged to this workspace
        if tiledWindowPositions.keys.contains(windowId) {
            // Remove from tracked positions
            tiledWindowPositions.removeValue(forKey: windowId)

            print(
                "Window \(windowId) removed from workspace \(title ?? "unknown")"
            )
            // Reapply tiling to adjust remaining windows
            reapplyTilingWithDelay()
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            print("Reapplying tiling for workspace \(self.title ?? "unknown")")
            self.applyTiling()
            self.captureWindowPositions()
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

        print(
            "Applying tiling mode: \(tilingEngine?.currentModeName) to workspace \(title ?? "unknown")"
        )
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
        WindowNotificationCenter.shared.postTilingModeChanged(self)
    }

    /// Set tiling mode by name
    func setTilingMode(_ modeName: String) {
        tilingEngine?.setTilingMode(modeName)

        // Apply immediately
        applyTiling()

        // Notify that tiling mode has changed
        WindowNotificationCenter.shared.postTilingModeChanged(self)
    }

    /// Cycle to next tiling mode
    @discardableResult
    func cycleToNextTilingMode() -> TilingStrategy? {
        guard let strategy = tilingEngine?.cycleToNextMode() else { return nil }

        // Apply immediately
        applyTiling()

        // Notify that tiling mode has changed
        WindowNotificationCenter.shared.postTilingModeChanged(self)

        return strategy
    }

    /// Update tiling configuration
    func setTilingConfiguration(_ config: TilingConfiguration) {
        tilingEngine?.config = config
        applyTiling()
    }
}
