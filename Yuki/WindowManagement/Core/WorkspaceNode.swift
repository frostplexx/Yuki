//
//  WorkspaceNode.swift
//  Yuki
//
//  Created by Daniel Inama on 10/3/25.
//

import Foundation
import CoreGraphics
import CoreFoundation
import Cocoa

/// WorkspaceNode represents a collection of windows with support for nested layouts
class WorkspaceNode: Node, ObservableObject, Equatable {
    
    static func == (lhs: WorkspaceNode, rhs: WorkspaceNode) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id: UUID
    var title: String?
    var children: [any Node] = []
    weak var parent: (any Node)?
    
    /// The monitor this workspace belongs to
    unowned var monitor: Monitor
    
    /// The tiling engine for this workspace with support for both simple and nested layouts
    lazy var tilingEngine: TilingEngine = {
        let engine = TilingEngine(workspace: self)
        return engine
    }()
    
    /// Cached positions for windows when in tiled mode
    var tiledWindowPositions: [CGWindowID: NSRect] = [:]
    
    /// Flag to indicate if tiling needs to be reapplied
    var needsReapplyTiling = false
    
    /// Timer for delayed tiling reapplication
    var reapplyTilingTimer: Timer?
    
    // MARK: - Initialization
    
    init(title: String? = nil, monitor: Monitor, useNestedLayouts: Bool = false) {
        self.id = UUID()
        self.title = title
        self.monitor = monitor
        
        // Initialize tiling engine later (lazy property)
    }
    
    // MARK: - Window Management
    
    /// Get all window nodes in this workspace
    func getAllWindowNodes() -> [WindowNode] {
        var result: [WindowNode] = []
        
        // Recursive function to collect window nodes
        func collectWindowNodes(from node: any Node) {
            if let windowNode = node as? WindowNode {
                result.append(windowNode)
            }
            
            for child in node.children {
                collectWindowNodes(from: child)
            }
        }
        
        // Start collection from workspace children
        for child in children {
            collectWindowNodes(from: child)
        }
        
        return result
    }
    
    /// Get only visible (non-minimized) window nodes
    func getVisibleWindowNodes() -> [WindowNode] {
        return getAllWindowNodes().filter { !$0.isMinimized }
    }
    
    /// Find a window node by its AXUIElement
    func findWindowNode(with axElement: AXUIElement) -> WindowNode? {
        return getAllWindowNodes().first { $0.window == axElement }
    }
    
    /// Find a window node by its system ID
    func findWindowNode(withID windowID: CGWindowID) -> WindowNode? {
        return getAllWindowNodes().first { $0.systemWindowID == windowID }
    }
    
    /// Add a window to this workspace
    func adoptWindow(_ window: AXUIElement) {
        // Check if we already have this window
        if let existingWindow = findWindowNode(with: window) {
            return
        }
        
        // Create a new window node
        let windowNode = WindowNode(window: window)
        
        // Add to this workspace
        addChild(windowNode)
        
        // Register ownership with window manager
        if let windowID = windowNode.systemWindowID {
            WindowManager.shared.registerWindowOwnership(windowID: windowID, workspaceID: id)
        }
    }
    
    /// Remove a window from this workspace
    func removeWindow(_ window: AXUIElement) {
        if let windowNode = findWindowNode(with: window) {
            // Unregister ownership
            if let windowID = windowNode.systemWindowID {
                WindowManager.shared.unregisterWindowOwnership(windowID: windowID)
            }
            
            // Remove from workspace
            removeChild(windowNode)
        }
    }
    
    // MARK: - Tiling Operations
    
    /// Apply tiling to all windows in this workspace
    func applyTiling(performanceMode: Bool = false) {
        tilingEngine.applyTiling(performanceMode: performanceMode) {
            // Capture window positions for future reference
            self.captureWindowPositions()
        }
    }
    
    /// Store current window positions
    func captureWindowPositions() {
        var positions: [CGWindowID: NSRect] = [:]
        
        for window in getAllWindowNodes() {
            if let windowID = window.systemWindowID, let frame = window.frame {
                positions[windowID] = frame
            }
        }
        
        tiledWindowPositions = positions
    }
    
    /// Reapply tiling with a short delay (to avoid rapid consecutive calls)
    func reapplyTilingWithDelay() {
        // Flag that tiling needs to be reapplied
        needsReapplyTiling = true
        
        // If timer already exists, just let it fire
        if reapplyTilingTimer != nil {
            return
        }
        
        // Create a new timer
        reapplyTilingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            guard let self = self, self.needsReapplyTiling else { return }
            
            self.needsReapplyTiling = false
            self.reapplyTilingTimer = nil
            
            // Apply tiling in the background
            DispatchQueue.global(qos: .userInteractive).async {
                DispatchQueue.main.async {
                    self.applyTiling()
                }
            }
        }
    }
    
    /// Set tiling mode
    func setTilingMode(_ modeName: String) {
        if tilingEngine.setLayoutType(named: modeName) {
            // Apply the new tiling mode immediately
            applyTiling()
        }
    }
    
    /// Cycle to the next tiling mode
    func cycleToNextTilingMode() {
        let newMode = tilingEngine.cycleToNextLayoutType()
        
        // Apply tiling immediately with the new mode
        if newMode != .float {
            applyTiling()
        }
    }
    
    // MARK: - Nested Layout Operations
    
    /// Toggle between simple and nested layout modes
    @discardableResult
    func toggleNestedLayoutMode() -> Bool {
        let result = tilingEngine.toggleNestedLayouts()
        applyTiling()
        return result
    }
    
    /// Set layout type for a region containing a specific window
    func setLayoutTypeForWindow(_ window: WindowNode, type: TilingEngine.LayoutType) -> Bool {
        let result = tilingEngine.setLayoutTypeForWindow(window, type: type)
        if result {
            // Apply the layout to see changes
            applyTiling()
        }
        return result
    }
    
    /// Split a region containing a window
    func splitNodeContaining(_ window: WindowNode,
                           ratio: CGFloat = 0.5,
                           firstType: TilingEngine.LayoutType,
                           secondType: TilingEngine.LayoutType) -> Bool {
        let result = tilingEngine.splitNodeContaining(window, ratio: ratio, firstType: firstType, secondType: secondType)
        if result {
            // Apply the layout to see changes
            applyTiling()
        }
        return result
    }
    
    // MARK: - Workspace Activation
    
    /// Determine if this workspace is currently active
    var isActive: Bool {
        return monitor.activeWorkspace?.id == id
    }
    
    /// Activate this workspace (make it visible)
    func activate() {
        if monitor.activeWorkspace?.id == id { return }
        
        // Deactivate previous workspace
        if let currentWorkspace = monitor.activeWorkspace {
            currentWorkspace.deactivate()
        }
        
        // Set as active workspace
        monitor.activeWorkspace = self
        
        // Restore window positions
        restoreWindowPositions()
        
        // Apply tiling after a short delay to allow windows to finish animating
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.applyTiling()
        }
    }
    
    /// Deactivate this workspace (hide its windows)
    func deactivate() {
        // Save current window positions
        captureWindowPositions()
        
        // Hide windows by moving them off-screen
        hideWindows()
    }
    
    /// Move all windows off-screen
    private func hideWindows() {
        let windows = getAllWindowNodes()
        
        // Offscreen position (just outside the visible area)
        let offscreenPosition = NSPoint(
            x: monitor.frame.maxX - 1.125,
            y: monitor.frame.maxY - 1.125
        )
        
        // Move windows in parallel for better performance
        DispatchQueue.concurrentPerform(iterations: windows.count) { index in
            let window = windows[index]
            window.move(to: offscreenPosition)
        }
    }
    
    /// Restore window positions from saved state
    private func restoreWindowPositions() {
        let windows = getAllWindowNodes()
        
        for window in windows {
            if let windowID = window.systemWindowID,
               let savedPosition = tiledWindowPositions[windowID] {
                // Restore to saved position
                window.setFrame(savedPosition)
            } else {
                // Place in center of screen if no saved position
                let screenCenter = NSPoint(
                    x: monitor.frame.midX - (window.size?.width ?? 800) / 2,
                    y: monitor.frame.midY - (window.size?.height ?? 600) / 2
                )
                window.move(to: screenCenter)
            }
        }
    }
}
