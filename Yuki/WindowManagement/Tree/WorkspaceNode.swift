//
//  WorkspaceRootNode.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Cocoa
import Foundation

/// Root node for a workspace
class WorkspaceNode: Node {

    var type: NodeType { .rootNode }
    var children: [any Node] = []
    var parent: (any Node)? = nil
    let id: UUID = UUID()
    var title: String?

    var monitor: Monitor

    // Store window elements directly along with their states
    private struct SavedWindowState {
        let window: AXUIElement
        let position: NSPoint
        let size: NSSize
        let title: String?
        let isFocused: Bool
    }

    // Array to store window states
    private var savedWindowStates: [SavedWindowState] = []
    
    var tilingWorkItem: DispatchWorkItem?
    let tilingQueue = DispatchQueue.global(qos: .userInteractive)
    
    
    var needsReapplyTiling = false
    var reapplyTilingTimer: Timer?

    private var cachedWindowNodes: [WindowNode]?
    private var windowNodesCacheInvalid = true

    // Use dispatch queues for parallel processing
    private let processingQueue = DispatchQueue(
        label: "com.yuki.workspace.processing", attributes: .concurrent)
    private let stateQueue = DispatchQueue(label: "com.yuki.workspace.state")

    // Cache window positions for faster restoration
    private var positionCache: [AXUIElement: NSPoint] = [:]
    private var sizeCache: [AXUIElement: NSSize] = [:]

    // Track if the workspace is currently active
    var isActive: Bool {
        return monitor.activeWorkspace?.id == self.id
    }

    /// Tiling engine for this workspace (lazy initialized)
    var tilingEngine: TilingEngine?

    init(title: String? = "Root", monitor: Monitor) {
        self.title = title
        self.monitor = monitor
        tilingEngine = TilingEngine(workspace: self)
        setupObservation()
    }

    func append(_ child: any Node) {
        var mutableChild = child
        mutableChild.parent = self
        children.append(mutableChild)
        windowNodesCacheInvalid = true
    }


    /// Finds a window node by system window ID
    /// - Parameter systemWindowID: The system window ID to find
    /// - Returns: The window node if found, nil otherwise
    func findWindowNode(systemWindowID: String) -> WindowNode? {
        // Direct check without nested loops for better performance
        for child in children where child.type == .window {
            if let windowNode = child as? WindowNode,
                windowNode.systemWindowID == systemWindowID
            {
                return windowNode
            }
        }

        // Then check containers
        for child in children where child.type == .container {
            if let container = child as? ContainerNode {
                for subChild in container.children
                where subChild.type == .window {
                    if let windowNode = subChild as? WindowNode,
                        windowNode.systemWindowID == systemWindowID
                    {
                        return windowNode
                    }
                }
            }
        }

        return nil
    }

    /// Find a window node for a specific application PID - optimized version
    func findWindowForApp(pid: pid_t) -> WindowNode? {
        // Get all windows first to avoid multiple calls
        let allNodes = getAllWindowNodes()
        return allNodes.first {
            WindowManager.shared.getPID(for: $0.window) == pid
        }
    }

    /// Gets all window nodes in the workspace - optimized version
    /// - Returns: Array of all window nodes
    func getAllWindowNodes() -> [WindowNode] {
        if !windowNodesCacheInvalid, let cached = cachedWindowNodes {
            return cached
        }
        
        var result: [WindowNode] = []
        result.reserveCapacity(children.count)
        
        // [existing code to populate result]
        
        // Cache the result
        cachedWindowNodes = result
        windowNodesCacheInvalid = false
        return result
    }
    
    // Find a window node by its AXUIElement
    func findWindowNodeByAXUIElement(_ element: AXUIElement) -> WindowNode? {
        let windowNodes = getAllWindowNodes()
        return windowNodes.first { node in
            node.window == element
        }
    }

    // Get all non-minimized window nodes in the workspace
    func getVisibleWindowNodes() -> [WindowNode] {
        let allWindows = getAllWindowNodes()
        return allWindows.filter { !$0.isMinimized }
    }

    // Check whether a window with a specific ID is minimized
    func isWindowMinimized(_ windowId: Int) -> Bool {
        guard let workspaceId = WindowManager.shared.windowOwnership[windowId],
            workspaceId == self.id,
            let windowElement = WindowManager.shared.windowDiscovery
                .getWindowElement(for: CGWindowID(windowId)),
            let windowNode = findWindowNodeByAXUIElement(windowElement)
        else {
            return false
        }

        return windowNode.isMinimized
    }

    /// Override adoptWindow to include ownership tracking and avoid duplicates
    func adoptWindow(_ window: AXUIElement) {
        // Get the window ID
        var windowId: CGWindowID = 0
        guard _AXUIElementGetWindow(window, &windowId) == .success else {
            print("Failed to get window ID during adoption")
            return
        }

        // Check if window is already owned by a workspace
        if let intId = Int(exactly: windowId),
            WindowManager.shared.windowOwnership[intId] == nil
        {
            // Create a window node
            let windowNode = WindowNode(window)

            // Add to ownership if not already tracked
            WindowManager.shared.windowOwnership[intId] = self.id

            // Add as a child
            self.children.append(windowNode)

            // Cache window position and size in a thread-safe way
            stateQueue.async {
                if let position = windowNode.position {
                    self.positionCache[window] = position
                }

                if let size = windowNode.size {
                    self.sizeCache[window] = size
                }
            }

            // Only move if the workspace is not active
            if !isActive {
                // Move off-screen immediately using GCD for performance
                processingQueue.async {
                    let offscreenPosition = NSPoint(
                        x: self.monitor.frame.maxX - 1.125,
                        y: self.monitor.frame.maxY - 1.125)
                    var cgPosition = CGPoint(
                        x: offscreenPosition.x, y: offscreenPosition.y)

                    if let positionValue = AXValueCreate(.cgPoint, &cgPosition)
                    {
                        DispatchQueue.main.async {
                            AXUIElementSetAttributeValue(
                                window, kAXPositionAttribute as CFString,
                                positionValue)
                        }
                    }
                }
            }
        }
    }

    func removeWindow(_ window: AXUIElement) {
        // Thread-safe removal using a dispatch queue
        stateQueue.async {
            // Get the window node and ID
            if let index = self.children.firstIndex(where: {
                guard let windowNode = $0 as? WindowNode else { return false }
                return windowNode.window == window
            }) {
                // Get window ID before removing
                if let windowNode = self.children[index] as? WindowNode,
                    let windowID = windowNode.systemWindowID,
                    let intID = Int(windowID)
                {
                    // Remove from ownership tracking
                    WindowManager.shared.windowOwnership.removeValue(
                        forKey: intID)
                }

                // Remove from caches
                self.positionCache.removeValue(forKey: window)
                self.sizeCache.removeValue(forKey: window)

                // Remove from children - must be on main thread as it affects UI
                DispatchQueue.main.async {
                    self.children.remove(at: index)
                }
            }
        }
    }

    /// Activate this workspace (make it visible and restore windows)
    func activate() {
        if monitor.activeWorkspace == self { return }

        // Make sure observation is set up
        setupObservation()

        // Deactivate previous workspace if different
        if let currentWorkspace = monitor.activeWorkspace,
            currentWorkspace.id != self.id
        {
            currentWorkspace.deactivate()
        }

        // Set as active workspace immediately
        monitor.activeWorkspace = self

        // Use a multithreaded restore method
        parallelRestoreWindowStates()

        // Apply tiling to the newly activated workspace
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print(
                "Activating workspace \(self.title ?? "unknown") - applying tiling"
            )
            self.applyTiling()

            // Notify that a workspace has been activated
//            WindowNotificationCenter.shared.postWorkspaceActivated(self)
        }
    }

    /// Deactivate this workspace (hide windows)
    func deactivate() {
        // Fast save and hide using parallel processing
        parallelSaveAndHideWindows()
    }

    // Fast save window state with minimal overhead
    func saveWindowState(_ window: WindowNode, isFocused: Bool = false) -> Bool
    {
        var positionResult: NSPoint?
        var sizeResult: NSSize?

        // Fetch position and size in a thread-safe manner
        stateQueue.sync {
            positionResult =
                self.positionCache[window.window] ?? window.position
            sizeResult = self.sizeCache[window.window] ?? window.size
        }

        guard let position = positionResult, let size = sizeResult else {
            return false
        }

        // Update cache thread-safely
        stateQueue.async {
            self.positionCache[window.window] = position
            self.sizeCache[window.window] = size

            // Store window state
            self.savedWindowStates.append(
                SavedWindowState(
                    window: window.window,
                    position: position,
                    size: size,
                    title: window.title,
                    isFocused: isFocused
                ))
        }

        return true
    }

    // Parallel save and hide all windows
    private func parallelSaveAndHideWindows() {
        // Get all windows once
        let windows = getAllWindowNodes()

        // Clear states in a thread-safe way
        stateQueue.async {
            self.savedWindowStates.removeAll(keepingCapacity: true)
        }

        // Get focused app PID
        let frontmostPID =
            NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0

        // Prepare the offscreen position once
        let offscreenPosition = NSPoint(
            x: self.monitor.frame.maxX - 1.125,
            y: self.monitor.frame.maxY - 1.125)
        var cgPosition = CGPoint(x: offscreenPosition.x, y: offscreenPosition.y)
        let positionValue = AXValueCreate(.cgPoint, &cgPosition)

        // Process windows in parallel
        let group = DispatchGroup()

        for window in windows {
            group.enter()

            processingQueue.async {
                // Get current position and size
                let position = window.position ?? offscreenPosition
                let size = window.size ?? NSSize(width: 800, height: 600)

                // Check if focused
                let windowPID = WindowManager.shared.getPID(for: window.window)
                let isFocused = windowPID == frontmostPID

                // Update cache and add to saved states in a thread-safe way
                self.stateQueue.async {
                    // Cache for future use
                    self.positionCache[window.window] = position
                    self.sizeCache[window.window] = size

                    // Store state
                    self.savedWindowStates.append(
                        SavedWindowState(
                            window: window.window,
                            position: position,
                            size: size,
                            title: window.title,
                            isFocused: isFocused
                        ))

                    // Move window off-screen - must be on main thread for accessibility
                    DispatchQueue.main.async {
                        if let posValue = positionValue {
                            AXUIElementSetAttributeValue(
                                window.window, kAXPositionAttribute as CFString,
                                posValue)
                        }
                        group.leave()
                    }
                }
            }
        }

    }

    // Parallel restoration of window states
    private func parallelRestoreWindowStates() {
        // Get saved states in a thread-safe way
        var statesToRestore: [SavedWindowState] = []

        stateQueue.sync {
            statesToRestore = self.savedWindowStates
        }

        if statesToRestore.isEmpty { return }

        // Create a mapping of windows to nodes for quick lookup
        var nodeMap: [AXUIElement: WindowNode] = [:]
        let currentWindows = getAllWindowNodes()

        for node in currentWindows {
            nodeMap[node.window] = node
        }

        // Track focused window
        var focusedWindow: AXUIElement? = nil

        // Use a dispatch group to track completion
        let group = DispatchGroup()

        // Process windows in parallel batches for better performance
        let chunkSize = max(
            1,
            statesToRestore.count / ProcessInfo.processInfo.activeProcessorCount
        )
        let chunks = stride(from: 0, to: statesToRestore.count, by: chunkSize)
            .map {
                Array(
                    statesToRestore[
                        $0..<min($0 + chunkSize, statesToRestore.count)])
            }

        // Process each chunk in parallel
        for chunk in chunks {
            group.enter()

            processingQueue.async {
                for savedState in chunk {
                    // Prepare position and size values
                    var cgPosition = CGPoint(
                        x: savedState.position.x, y: savedState.position.y)
                    var cgSize = CGSize(
                        width: savedState.size.width,
                        height: savedState.size.height)

                    if let positionValue = AXValueCreate(.cgPoint, &cgPosition),
                        let sizeValue = AXValueCreate(.cgSize, &cgSize)
                    {

                        // Apply on main thread since accessibility API requires it
                        DispatchQueue.main.async {
                            // Set size first, then position
                            AXUIElementSetAttributeValue(
                                savedState.window, kAXSizeAttribute as CFString,
                                sizeValue)
                            AXUIElementSetAttributeValue(
                                savedState.window,
                                kAXPositionAttribute as CFString, positionValue)
                        }

                        // Track focused window
                        if savedState.isFocused {
                            self.stateQueue.async {
                                focusedWindow = savedState.window
                            }
                        }
                    }
                }
                group.leave()
            }
        }

        // After all windows are restored, focus the appropriate window
        group.notify(queue: .main) {
            // Get the focused window in a thread-safe way
            self.stateQueue.sync {
                if let focusedWindow = focusedWindow {
                    // Get the process ID
                    var pid: pid_t = 0
                    AXUIElementGetPid(focusedWindow, &pid)

                    // Activate the app
                    if let app = NSRunningApplication(processIdentifier: pid) {
                        app.activate(options: .activateIgnoringOtherApps)

                        // Focus the window
                        AXUIElementSetAttributeValue(
                            focusedWindow, kAXMainAttribute as CFString,
                            true as CFTypeRef)
                        AXUIElementSetAttributeValue(
                            focusedWindow, kAXFocusedAttribute as CFString,
                            true as CFTypeRef)
                    }
                }
            }
        }
    }
    
    // Add to WorkspaceNode.swift

    /// Remove a window node without triggering tiling updates
    /// - Parameter windowNode: The window node to remove
    func removeWithoutUpdating(_ windowNode: WindowNode) {
        // First, remove from window ownership tracking if needed
        if let windowID = windowNode.systemWindowID, let intID = Int(windowID) {
            WindowManager.shared.windowOwnership.removeValue(forKey: intID)
            
            // Also remove from WindowManager's node cache
            WindowManager.shared.windowNodeCache.removeValue(forKey: intID)
        }
        
        // Remove the node from children collection
        children.removeAll {
            let nodeChild = ($0 as (any Node))
            return nodeChild.id == windowNode.id
        }
        
        // Invalidate window list cache without triggering updates
        if let cachedWindowNodes = (self as WorkspaceNode).cachedWindowNodes {
            self.cachedWindowNodes = cachedWindowNodes.filter { $0.id != windowNode.id }
        } else {
            // Mark cache as invalid
            windowNodesCacheInvalid = true
        }
        
        // Do not apply tiling here - will be done later if needed
    }
}

