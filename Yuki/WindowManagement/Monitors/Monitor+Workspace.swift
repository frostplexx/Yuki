//
//  MonitorWindowManager.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Cocoa
import Foundation

/// Extension to Monitor class to handle window management operations
extension Monitor {
    // MARK: - Window Management Properties

    /// Dictionary to store original window positions for restoration
    private struct WindowManagementState {
        static var originalWindowData: [Int: WindowPositionData] = [:]
    }

    /// Hides all windows in a workspace by moving them off-screen
    func hideWorkspaceWindows(_ workspace: Workspace) {
        for windowNode in workspace.root.getAllWindowNodes() {
            // Store the current position and size
            if let systemWindowID = windowNode.systemWindowID {
                // Don't overwrite existing data
                if WindowManagementState.originalWindowData[systemWindowID]
                    == nil
                {
                    storeWindowData(
                        windowNode: windowNode, windowId: systemWindowID)
                }

                // Choose the right corner to hide windows (bottom right)
                hideWindowInBottomRightCorner(windowNode)
            }
        }
    }

    /// Shows all windows in a workspace by restoring their original positions
    func showWorkspaceWindows(_ workspace: Workspace) {
        // First disable enhanced user interface to prevent resizing issues
        disableEnhancedUserInterface(for: workspace)

        // Get all window nodes that need to be restored
        let windowNodes = workspace.root.getAllWindowNodes()

        // First pass: Restore each window's size and position
        for windowNode in windowNodes {
            if let systemWindowID = windowNode.systemWindowID,
                let savedData = WindowManagementState.originalWindowData[
                    systemWindowID]
            {

                print(
                    "Restoring window \(systemWindowID) to position: \(savedData.position), size: \(savedData.size.width)x\(savedData.size.height)"
                )

                // First resize the window
                disableAnimations(for: windowNode) {
                    windowNode.resize(to: savedData.size)
                }

                // Then move it to the correct position
                disableAnimations(for: windowNode) {
                    windowNode.move(to: savedData.position)
                }

                // Clear the saved data after restoration
                WindowManagementState.originalWindowData.removeValue(
                    forKey: systemWindowID)
            } else {
                // If we don't have saved data, position in default location
                positionWindowInDefaultLocation(windowNode)
            }
        }

        // Second pass: Raise each window to ensure proper stacking
        for windowNode in windowNodes {
            windowNode.focus()
        }

        // Apply tiling layout if needed
        if workspace.root.type == .hStack || workspace.root.type == .vStack {
            //            applyTilingLayout(workspace)
        }
    }

    // MARK: - Window Operations

    /// Assigns a window to the active workspace on this monitor
    /// - Parameters:
    ///   - window: The window element to assign
    ///   - windowId: The system window ID
    ///   - title: Optional title for the window
    /// - Returns: The created window node, or nil if no active workspace
    func assignWindow(window: AXUIElement, windowId: Int, title: String? = nil)
        -> WindowNode?
    {
        guard let workspace = activeWorkspace else {
            return nil
        }

        // Create window node
        let windowNode = WindowNode(
            window: window, systemWindowID: windowId, title: title)

        // Disable enhanced user interface for this window
        disableEnhancedUserInterfaceForWindow(window)

        // Add to workspace root
        var root = workspace.root
        root.append(windowNode)

        return windowNode
    }

    /// Stores a window's position and size data for later restoration
    /// - Parameters:
    ///   - windowNode: The window node
    ///   - windowId: The window ID
    private func storeWindowData(windowNode: WindowNode, windowId: Int) {
        guard let position = windowNode.position,
            let size = windowNode.size
        else { return }

        // Store both position and size together in a single structure
        WindowManagementState.originalWindowData[windowId] = WindowPositionData(
            position: position, size: size)

        print(
            "Stored window \(windowId) position: \(position), size: \(size.width)x\(size.height)"
        )
    }

    /// Hides a window in the bottom right corner of the monitor
    /// - Parameter windowNode: The window to hide
    private func hideWindowInBottomRightCorner(_ windowNode: WindowNode) {
        // Get the window's current size
        //        guard let windowSize = windowNode.size else { return }

        // Calculate a position in the bottom right corner of the screen
        // Position the window so it's mostly off-screen, but with a small part visible
        // We'll keep 5 pixels visible on each edge to make sure it's accessible
        let hiddenPosition = NSPoint(
            x: visibleFrame.maxX - 0.125,
            y: visibleFrame.maxY - 0.125
        )

        // Move the window with animations disabled
        disableAnimations(for: windowNode) {
            windowNode.move(to: hiddenPosition)
        }

        print("Hid window to bottom right: \(hiddenPosition)")
    }

    /// Positions a window in a default location on the monitor
    /// - Parameter windowNode: The window to position
    private func positionWindowInDefaultLocation(_ windowNode: WindowNode) {
        // If we don't have a saved position, place it in a default location
        // Use the center of the monitor with reasonable default size
        let defaultSize = NSSize(
            width: visibleFrame.width * 0.6, height: visibleFrame.height * 0.6)
        let defaultX = visibleFrame.midX - (defaultSize.width / 2)
        let defaultY = visibleFrame.midY - (defaultSize.height / 2)
        let defaultPosition = NSPoint(x: defaultX, y: defaultY)

        disableAnimations(for: windowNode) {
            windowNode.resize(to: defaultSize)
            windowNode.move(to: defaultPosition)
        }

        print("Positioned window in default location: \(defaultPosition)")
    }

    /// Disables enhanced user interface for a window
    /// - Parameter window: The window to modify
    private func disableEnhancedUserInterfaceForWindow(_ window: AXUIElement) {
        //        let app = AXUIElementCreateApplication(window.pid())
        window.set(Ax.enhancedUserInterfaceAttr, false)
    }

    // MARK: - Animation and Enhanced User Interface

    /// Disable Enhanced User Interface for all windows in a workspace
    /// This prevents incorrect window resizing (related to issue #285)
    private func disableEnhancedUserInterface(for workspace: Workspace) {
        for windowNode in workspace.root.getAllWindowNodes() {
            _ = disableAnimations(for: windowNode) {
                windowNode.window.set(Ax.enhancedUserInterfaceAttr, false)
            }
        }
    }

    /// Temporarily disables animations while performing an operation
    /// - Parameters:
    ///   - windowNode: The window node to affect
    ///   - operation: The operation to perform with animations disabled
    /// - Returns: The result of the operation
    private func disableAnimations<T>(
        for windowNode: WindowNode, _ operation: () -> T
    ) -> T {
        // Get the app's accessibility element
        let app = AXUIElementCreateApplication(windowNode.window.pid())

        // Check if enhanced user interface is enabled
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            app, "AXEnhancedUserInterface" as CFString, &value)
        let wasEnabled = (result == .success && (value as? Bool) == true)

        // Disable enhanced user interface if it was enabled
        if wasEnabled {
            AXUIElementSetAttributeValue(
                app, "AXEnhancedUserInterface" as CFString, false as CFTypeRef)
        }

        // Perform the operation
        let operationResult = operation()

        // Restore the previous state
        if wasEnabled {
            AXUIElementSetAttributeValue(
                app, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
        }

        return operationResult
    }

    // MARK: - Workspace Window Management

    /// Activates the specified workspace on this monitor
    /// - Parameter workspace: The workspace to activate
    /// - Returns: True if activation was successful
    @discardableResult
    func activateWorkspace(_ workspace: Workspace) -> Bool {
        // Ensure the workspace belongs to this monitor
        guard workspaces.contains(where: { $0.id == workspace.id }) else {
            return false
        }

        // Don't do anything if it's already active
        if activeWorkspace?.id == workspace.id {
            return true
        }

        // Hide windows from current workspace if needed
        if let current = activeWorkspace {
            hideWorkspaceWindows(current)
        }

        // Set as active workspace
        activeWorkspace = workspace

        // Show windows for new workspace
        showWorkspaceWindows(workspace)

        return true
    }
}
