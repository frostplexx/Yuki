//
//  WorkspaceCleanup.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa

// MARK: - Workspace Container Cleanup

extension WorkspaceRootNode {
    /// Ensures there's exactly one default HStack container and fixes the window hierarchy
    func ensureProperStructure() {
        // Find all direct child containers
        var containers: [ContainerNode] = []
        for child in children {
            if let container = child as? ContainerNode {
                containers.append(container)
            }
        }
        
        // If there are no containers, create a default one
        if containers.isEmpty {
            let container = ContainerNode(type: .hStack, title: "Default Layout")
            var mutableSelf = self
            mutableSelf.append(container)
            return
        }
        
        // Find containers by type
        let hstackContainers = containers.filter { $0.type == .hStack }
        
        // If there's already exactly one HStack container, we're done
        if hstackContainers.count == 1 {
            return
        }
        
        // If there are multiple HStack containers, merge them
        if hstackContainers.count > 1 {
            // Keep the first one as primary
            let primaryContainer = hstackContainers[0]
            var mutablePrimaryContainer = primaryContainer
            
            // Move all windows from other containers to the primary one
            for container in hstackContainers.dropFirst() {
                // Get all window nodes
                for child in container.children {
                    if let windowNode = child as? WindowNode {
                        // Remove from current container
                        var mutableContainer = container
                        mutableContainer.remove(windowNode)
                        
                        // Add to primary container
                        mutablePrimaryContainer.append(windowNode)
                    }
                }
                
                // Remove the now-empty container
                var mutableSelf = self
                mutableSelf.remove(container)
            }
            
            print("Merged \(hstackContainers.count) HStack containers")
        }
        
        // Move any direct window children to the HStack container
        let directWindowNodes = children.compactMap { $0 as? WindowNode }
        if !directWindowNodes.isEmpty {
            let container = hstackContainers.first ?? {
                // Create container if none exists
                let newContainer = ContainerNode(type: .hStack, title: "Default Layout")
                var mutableSelf = self
                mutableSelf.append(newContainer)
                return newContainer
            }()
            
            var mutableContainer = container
            for windowNode in directWindowNodes {
                var mutableSelf = self
                mutableSelf.remove(windowNode)
                mutableContainer.append(windowNode)
            }
            
            print("Moved \(directWindowNodes.count) windows from root to container")
        }
    }
}

// MARK: - Window Node Extension for BSP Tiling

extension WindowNode {
    /// Sets the position and size of the window for tiling
    /// - Parameters:
    ///   - rect: The rectangle to position and size the window
    ///   - animated: Whether to animate the change
    func setFrame(_ rect: NSRect, animated: Bool = false) {
        // First disable animations if needed
        let performOperation = { [weak self] in
            guard let self = self else { return }
            
            // Resize and reposition
            self.resize(to: CGSize(width: rect.width, height: rect.height))
            self.move(to: NSPoint(x: rect.minX, y: rect.minY))
        }
        
        // Execute with or without animation disabling
        if !animated {
            let app = AXUIElementCreateApplication(window.pid())
            
            // Check if enhanced user interface is enabled
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(app, "AXEnhancedUserInterface" as CFString, &value)
            let wasEnabled = (result == .success && (value as? Bool) == true)
            
            // Disable enhanced user interface if it was enabled
            if wasEnabled {
                AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, false as CFTypeRef)
            }
            
            performOperation()
            
            // Restore the previous state
            if wasEnabled {
                AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
            }
        } else {
            performOperation()
        }
    }
}

// MARK: - WindowManager Extension

extension WindowManager {
    /// Cleans up all workspace structures
    func cleanupAllWorkspaces() {
        for monitor in monitors {
            for workspace in monitor.workspaces {
                workspace.cleanupStructure()
            }
        }
        
        print("Cleaned up all workspace structures")
    }
    
    /// Gets a fresh window list from the system
    /// - Returns: Array of visible window info dictionaries
    func getVisibleWindowList() -> [[String: Any]] {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        
        guard let windowList = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]]
        else { return [] }
        
        return windowList.filter { ($0["kCGWindowLayer"] as? Int) == 0 }
    }
    
    /// Refreshes all window data from the system and applies BSP tiling
    func refreshAndApplyBSP() {
        // First clean up workspace structures
        cleanupAllWorkspaces()
        
        // Then refresh windows
        refreshWindows()
        
    }
}
