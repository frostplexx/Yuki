//
//  Monitor.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa

/// Represents a physical display/monitor in the system
class Monitor: Identifiable, ObservableObject {
    // MARK: - Properties
    
    /// Unique identifier for this monitor
    let id: Int
    
    /// The complete frame of the monitor
    let frame: NSRect
    
    /// The visible frame (excludes Dock, menu bar, etc.)
    let visibleFrame: NSRect
    
    /// Human-readable name of the monitor
    let name: String
    
    /// Workspaces available on this monitor
    @Published var workspaces: [WorkspaceNode] = []
    
    /// Currently active workspace on this monitor
    @Published var activeWorkspace: WorkspaceNode?
    
    
    private let tilingEngine: TilingEngine = TilingEngine()

    /// Whether this monitor contains the mouse pointer
    var hasMousePointer: Bool {
        let mouseLocation = NSEvent.mouseLocation
        return NSPointInRect(mouseLocation, frame)
    }
    
    // MARK: - Computed Properties
    
    /// The width of the monitor in points
    var width: CGFloat { frame.width }
    
    /// The height of the monitor in points
    var height: CGFloat { frame.height }
    
    /// Whether this is the main monitor (contains menu bar)
    var isMain: Bool {
        if let mainScreen = NSScreen.main {
            return NSEqualRects(frame, mainScreen.frame)
        }
        return false
    }
    
    /// The bottom left corner of the monitor
    var bottomLeft: NSPoint {
        return NSPoint(x: frame.minX, y: frame.minY)
    }
    
    /// The bottom right corner of the monitor
    var bottomRight: NSPoint {
        return NSPoint(x: frame.maxX, y: frame.minY)
    }
    
    /// The top left corner of the monitor
    var topLeft: NSPoint {
        return NSPoint(x: frame.minX, y: frame.maxY)
    }
    
    /// The top right corner of the monitor
    var topRight: NSPoint {
        return NSPoint(x: frame.maxX, y: frame.maxY)
    }
    
    /// Returns the center point of the monitor
    var center: NSPoint {
        return NSPoint(
            x: frame.origin.x + frame.width / 2,
            y: frame.origin.y + frame.height / 2
        )
    }
    
    // MARK: - Initialization
    
    /// Initialize a new monitor with the given properties
    /// - Parameters:
    ///   - id: Unique identifier for this monitor
    ///   - frame: The complete frame of the monitor
    ///   - visibleFrame: The usable frame of the monitor (excluding system UI)
    ///   - name: Human-readable name of the monitor
    init(id: Int, frame: NSRect, visibleFrame: NSRect, name: String) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.name = name
        initDefaultWorkspaces()
        
        
        // Adopt all windows
//        for windowInfo in visibleWindows {
//            guard let windowId = windowInfo["kCGWindowNumber"] as? Int,
//                  let ownerPID = windowInfo["kCGWindowOwnerPID"] as? Int32,
//                  let bounds = windowInfo["kCGWindowBounds"] as? [String: Any],
//                  let x = bounds["X"] as? CGFloat,
//                  let y = bounds["Y"] as? CGFloat
//            else { continue }
            
            // Skip windows that are already assigned
//            if WindowManager.shared.windowOwnership[windowId] != nil {
//                continue
//            }
            
            // Find which monitor contains this window
//            let windowPosition = NSPoint(x: x, y: y)
//            let targetMonitor = self.contains(
//                point: windowPosition
//            )
            
            // Get the active workspace for this monitor
//            guard let targetMonitor = targetMonitor,
//                  let targetWorkspace = targetMonitor.activeWorkspace ?? targetMonitor.workspaces.first
//            else { continue }
            
            // Try to get the window element
//            if let window = WindowManager.shared.getWindowElement(
//                for: CGWindowID(windowId)
//            ) {
                // Create a window node
//                let windowNode = WindowNode(window)
                
//                workspaces.first!.adoptWindow(window)
                
                // Add to workspace's default container
//                targetWorkspace.addWindowToDefaultContainer(windowNode)
                
                // Register ownership
//                windowOwnership[windowId] = targetWorkspace.id
                
                // Disable enhanced user interface for better tiling
//                accessibilityService.disableEnhancedUserInterface(for: window)
//            }
//        }
    }
    
    // MARK: - Workspace Management
    
    /// Creates a new workspace on this monitor
    /// - Parameter name: The name for the new workspace
    /// - Returns: The newly created workspace
//    func createWorkspace(name: String) -> Workspace {
//        let workspace = Workspace(id: UUID(), name: name)
//        workspace.monitor = self
//        workspaces.append(workspace)
//        
//        // If this is the first workspace, make it active
//        if activeWorkspace == nil {
//            activeWorkspace = workspace
//        }
//        
//        return workspace
//    }
    
    /// Removes a workspace from this monitor
    /// - Parameter workspace: The workspace to remove
    /// - Returns: True if removal was successful
//    @discardableResult
//    func removeWorkspace(_ workspace: Workspace) -> Bool {
//        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else {
//            return false
//        }
//        
//        // If removing active workspace, set a new active one
//        if activeWorkspace?.id == workspace.id {
//            if workspaces.count > 1 {
//                // Select previous or next workspace
//                let newIndex = index > 0 ? index - 1 : (index + 1 < workspaces.count ? index + 1 : nil)
//                if let newIndex = newIndex {
//                    activeWorkspace = workspaces[newIndex]
//                } else {
//                    activeWorkspace = nil
//                }
//            } else {
//                activeWorkspace = nil
//            }
//        }
//        
//        workspaces.remove(at: index)
//        return true
//    }
    
    
    

    // MARK: - Basic Window Management
    
    /// Checks if a point is within this monitor's frame
    /// - Parameter point: The point to check
    /// - Returns: True if the point is within this monitor's frame
    func contains(point: NSPoint) -> Bool {
        return NSPointInRect(point, frame)
    }
}

// MARK: - Equatable Conformance

extension Monitor: Equatable {
    static func == (lhs: Monitor, rhs: Monitor) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable Conformance

extension Monitor: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
