// TilingEngine.swift
// Unified tiling engine with support for both simple and nested layouts

import Cocoa
import Foundation

/// Unified tiling engine that supports both simple and nested layouts
class TilingEngine {
    // MARK: - Enums
    
    /// Available tiling modes/layout types
    enum LayoutType: String, CaseIterable, Equatable {
        case bsp = "bsp"     // Binary space partitioning
        case hstack = "hstack"  // Horizontal stack
        case vstack = "vstack"  // Vertical stack
        case zstack = "zstack"  // Windows stacked on top of each other
        case float = "float"   // Freely positioned windows
        
        var description: String {
            switch self {
            case .bsp: return "Binary Space Partitioning"
            case .hstack: return "Horizontal Stack"
            case .vstack: return "Vertical Stack"
            case .zstack: return "Stacked Windows"
            case .float: return "Free Floating"
            }
        }
    }
    
    // MARK: - Layout Node Structure
    
    /// Represents a node in the layout tree
    class LayoutNode: Identifiable {
        /// Unique identifier for the node
        let id = UUID()
        
        /// Layout type for this region
        var layoutType: LayoutType
        
        /// Windows assigned to this node
        var windows: [WindowNode] = []
        
        /// Child layout nodes
        var children: [LayoutNode] = []
        
        /// Split ratio for dividing the space (0.0-1.0)
        var splitRatio: CGFloat = 0.5
        
        /// Parent node (nil for root)
        weak var parent: LayoutNode?
        
        /// Region assigned to this node
        var region: NSRect = .zero
        
        /// Whether node is expandable
        var isExpandable: Bool {
            return layoutType != .float && layoutType != .zstack
        }
        
        init(layoutType: LayoutType, windows: [WindowNode] = []) {
            self.layoutType = layoutType
            self.windows = windows
        }
        
        /// Split this node into two child nodes
        func split(ratio: CGFloat = 0.5, firstType: LayoutType, secondType: LayoutType) -> (LayoutNode, LayoutNode) {
            // Create the new layout nodes
            let first = LayoutNode(layoutType: firstType)
            let second = LayoutNode(layoutType: secondType)
            
            // Set parent relationships
            first.parent = self
            second.parent = self
            
            // Set the split ratio
            self.splitRatio = ratio.clamped(to: 0.1...0.9)
            
            // Add to children array
            children = [first, second]
            
            // Distribute existing windows
            if !windows.isEmpty {
                let midpoint = Int(ceil(CGFloat(windows.count) * ratio))
                first.windows = Array(windows.prefix(midpoint))
                second.windows = Array(windows.suffix(from: midpoint))
            }
            
            // Clear windows from this parent node (now distributed to children)
            windows = []
            
            return (first, second)
        }
        
        /// Add a window to this node
        func addWindow(_ window: WindowNode) {
            if children.isEmpty {
                windows.append(window)
            } else {
                // Add to child with fewer windows
                let childWithFewerWindows = children.min {
                    $0.totalWindowCount < $1.totalWindowCount
                } ?? children[0]
                childWithFewerWindows.addWindow(window)
            }
        }
        
        /// Remove a window from this node or its children
        func removeWindow(_ window: WindowNode) -> Bool {
            // Check if window is in this node
            if let index = windows.firstIndex(where: { $0.id == window.id }) {
                windows.remove(at: index)
                return true
            }
            
            // Check children recursively
            for child in children {
                if child.removeWindow(window) {
                    return true
                }
            }
            
            return false
        }
        
        /// Get total window count including children
        var totalWindowCount: Int {
            let directWindowCount = windows.count
            let childWindowCount = children.reduce(0) { $0 + $1.totalWindowCount }
            return directWindowCount + childWindowCount
        }
        
        /// Find layout node containing a specific window
        func findNodeContaining(_ window: WindowNode) -> LayoutNode? {
            // Check if window is in this node
            if windows.contains(where: { $0.id == window.id }) {
                return self
            }
            
            // Check children recursively
            for child in children {
                if let node = child.findNodeContaining(window) {
                    return node
                }
            }
            
            return nil
        }
    }
    
    // MARK: - Properties
    
    /// Reference to the workspace this engine manages
    weak var workspace: WorkspaceNode?
    
    /// Root layout node for nested layouts
    var rootNode: LayoutNode
    
    /// Whether to use nested layouts (tree structure) vs. flat layouts
    var useNestedLayouts: Bool = false
    
    /// Current layout type for simple mode
    private(set) var currentLayoutType: LayoutType = .hstack
    
    /// Configuration for tiling
    var config: TilingConfiguration
    
    /// Queue for background calculations
    private let calculationQueue = DispatchQueue(
        label: "com.yuki.tilingCalculation",
        qos: .userInteractive,
        attributes: .concurrent
    )
    
    /// Synchronization queue
    let syncQueue = DispatchQueue(
        label: "com.yuki.tilingSync"
    )
    
    /// Cache for window float decisions
    var floatDecisionCache = NSCache<NSNumber, NSNumber>()
    
    // MARK: - Initialization
    
    /// Initialize with a workspace and default layout type
    init(workspace: WorkspaceNode? = nil, initialLayoutType: LayoutType = .hstack) {
        self.workspace = workspace
        self.currentLayoutType = initialLayoutType
        self.rootNode = LayoutNode(layoutType: initialLayoutType)
        self.config = TilingConfiguration()
    }
    
    // MARK: - Layout Operations
    
    /// Apply current layout to windows
    func applyTiling(performanceMode: Bool = false, completion: (() -> Void)? = nil) {
        guard let workspace = workspace else {
            completion?()
            return
        }
        
        // Get all visible, non-minimized windows
        let allVisibleWindows = workspace.getVisibleWindowNodes()
        
        // Skip empty workspaces
        if allVisibleWindows.isEmpty {
            completion?()
            return
        }
        
        // Filter windows that should be tiled vs. float
        let windowsToTile = allVisibleWindows.filter { !shouldWindowFloat($0) }
        
        // Skip if no windows to tile or in float mode
        if windowsToTile.isEmpty ||
           (useNestedLayouts ? rootNode.layoutType == .float : currentLayoutType == .float) {
            completion?()
            return
        }
        
        // Get available area
        let availableRect = workspace.monitor.visibleFrame
        
        // PERFORMANCE CRITICAL PATH FOR WINDOW CLOSING
        if performanceMode && Thread.isMainThread && windowsToTile.count < 8 {
            if useNestedLayouts {
                // Update tree and apply directly
                syncQueue.sync {
                    rebuildLayoutTree(with: windowsToTile)
                    rootNode.region = availableRect
                }
                let layouts = calculateLayoutsForNode(rootNode)
                applyCalculatedLayouts(layouts)
            } else {
                // Calculate and apply directly for simple layouts
                let layouts = calculateSimpleLayouts(
                    windows: windowsToTile,
                    in: availableRect,
                    using: currentLayoutType
                )
                applyCalculatedLayouts(layouts)
            }
            completion?()
            return
        }
        
        // Standard path for non-critical updates
        calculationQueue.async {
            var layouts: [WindowNode: NSRect] = [:]
            
            if self.useNestedLayouts {
                // Calculate layouts using tree structure
                self.syncQueue.sync {
                    self.rebuildLayoutTree(with: windowsToTile)
                    self.rootNode.region = availableRect
                }
                layouts = self.calculateLayoutsForNode(self.rootNode)
            } else {
                // Calculate layouts using simple mode
                layouts = self.calculateSimpleLayouts(
                    windows: windowsToTile,
                    in: availableRect,
                    using: self.currentLayoutType
                )
            }
            
            // Apply layouts on main thread
            DispatchQueue.main.async {
                self.applyCalculatedLayouts(layouts)
                completion?()
            }
        }
    }
    
    // MARK: - Simple Mode Operations
    
    /// Set layout type for simple mode
    @discardableResult
    func setLayoutType(_ layoutType: LayoutType) -> Bool {
        let oldType = currentLayoutType
        currentLayoutType = layoutType
        
        // In nested mode, also update root layout type
        if useNestedLayouts {
            rootNode.layoutType = layoutType
        }
        
        return oldType != layoutType
    }
    
    /// Set layout type by name
    @discardableResult
    func setLayoutType(named typeName: String) -> Bool {
        if let layoutType = LayoutType(rawValue: typeName.lowercased()) {
            return setLayoutType(layoutType)
        }
        return false
    }
    
    /// Cycle to the next layout type
    @discardableResult
    func cycleToNextLayoutType() -> LayoutType {
        let allTypes = LayoutType.allCases
        guard let currentIndex = allTypes.firstIndex(of: currentLayoutType) else {
            // Fallback if current type not found
            let newType = allTypes[0]
            setLayoutType(newType)
            return newType
        }
        
        let nextIndex = (currentIndex + 1) % allTypes.count
        let newType = allTypes[nextIndex]
        setLayoutType(newType)
        return newType
    }
    
    /// Calculate layouts for simple mode
    private func calculateSimpleLayouts(
        windows: [WindowNode],
        in availableRect: NSRect,
        using layoutType: LayoutType
    ) -> [WindowNode: NSRect] {
        // Apply outer gap
        let rect = NSRect(
            x: availableRect.minX + config.outerGap,
            y: availableRect.minY + config.outerGap,
            width: availableRect.width - (2 * config.outerGap),
            height: availableRect.height - (2 * config.outerGap)
        )
        
        switch layoutType {
        case .bsp:
            return calculateBSPLayout(windows: windows, rect: rect, orientation: .h)
        case .hstack:
            return calculateHStackLayout(windows: windows, rect: rect)
        case .vstack:
            return calculateVStackLayout(windows: windows, rect: rect)
        case .zstack:
            return calculateZStackLayout(windows: windows, rect: rect)
        case .float:
            // Return current positions
            var layouts: [WindowNode: NSRect] = [:]
            for window in windows {
                if let frame = window.frame {
                    layouts[window] = frame
                }
            }
            return layouts
        }
    }
    
    // MARK: - Nested Layout Operations
    
    /// Toggle between nested and simple layout modes
    @discardableResult
    func toggleNestedLayouts() -> Bool {
        useNestedLayouts = !useNestedLayouts
        
        // Ensure root node has current layout type
        if useNestedLayouts {
            rootNode.layoutType = currentLayoutType
        }
        
        return useNestedLayouts
    }
    
    /// Set layout type for a region containing a specific window
    func setLayoutTypeForWindow(_ window: WindowNode, type: LayoutType) -> Bool {
        guard useNestedLayouts else { return false }
        
        return syncQueue.sync {
            guard let node = rootNode.findNodeContaining(window) else {
                return false
            }
            
            node.layoutType = type
            return true
        }
    }
    
    /// Split a region containing a window
    func splitNodeContaining(_ window: WindowNode,
                           ratio: CGFloat = 0.5,
                           firstType: LayoutType,
                           secondType: LayoutType) -> Bool {
        guard useNestedLayouts else { return false }
        
        return syncQueue.sync {
            guard let node = rootNode.findNodeContaining(window),
                  node.children.isEmpty else {
                return false
            }
            
            // Find index of window to determine which side it should go
            let windowIndex = node.windows.firstIndex { $0.id == window.id } ?? 0
            let isFirst = windowIndex < node.windows.count / 2
            
            // Split the node
            let (first, second) = node.split(ratio: ratio, firstType: firstType, secondType: secondType)
            
            // Ensure window is in the correct child
            if isFirst && !first.windows.contains(where: { $0.id == window.id }) {
                if let idx = second.windows.firstIndex(where: { $0.id == window.id }) {
                    let win = second.windows.remove(at: idx)
                    first.windows.append(win)
                }
            } else if !isFirst && !second.windows.contains(where: { $0.id == window.id }) {
                if let idx = first.windows.firstIndex(where: { $0.id == window.id }) {
                    let win = first.windows.remove(at: idx)
                    second.windows.append(win)
                }
            }
            
            return true
        }
    }
    
    /// Rebuild the layout tree when window configuration changes significantly
    private func rebuildLayoutTree(with windows: [WindowNode]) {
        // If tree is empty or windows count changed dramatically, rebuild it
        let countDifference = abs(rootNode.totalWindowCount - windows.count)
        let needsRebuild = rootNode.totalWindowCount == 0 ||
                           windows.count == 0 ||
                           countDifference > 2
        
        if needsRebuild {
            // Create new root with the same layout type
            let layoutType = rootNode.layoutType
            rootNode = LayoutNode(layoutType: layoutType)
            
            // Add all windows to the new root
            rootNode.windows = windows
            
            // If there are enough windows and the layout type is divisible, create child nodes
            if windows.count > 1 && layoutType != .zstack && layoutType != .float {
                createInitialSplit(for: rootNode)
            }
        } else {
            // Update existing tree
            updateExistingLayoutTree(with: windows)
        }
    }
    
    /// Create initial split for a layout node
    private func createInitialSplit(for node: LayoutNode) {
        // Choose child layout types based on parent
        let firstChildType: LayoutType
        let secondChildType: LayoutType
        
        switch node.layoutType {
        case .hstack:
            // For hstack, split into two hstacks or mix with vstack
            firstChildType = .hstack
            secondChildType = node.windows.count > 3 ? .vstack : .hstack
            
        case .vstack:
            // For vstack, split into two vstacks or mix with hstack
            firstChildType = .vstack
            secondChildType = node.windows.count > 3 ? .hstack : .vstack
            
        case .bsp:
            // For bsp, alternate horizontal/vertical splits
            if node.parent?.layoutType == .vstack {
                firstChildType = .hstack
                secondChildType = .hstack
            } else {
                firstChildType = .vstack
                secondChildType = .vstack
            }
            
        default:
            // Other types don't typically get split but we'll handle anyway
            firstChildType = .hstack
            secondChildType = .hstack
        }
        
        // Create the split
        _ = node.split(ratio: 0.5, firstType: firstChildType, secondType: secondChildType)
        
        // Recursively create splits if needed
        for child in node.children {
            if child.windows.count > 2 && child.isExpandable {
                createInitialSplit(for: child)
            }
        }
    }
    
    /// Update existing layout tree with current windows
    private func updateExistingLayoutTree(with windows: [WindowNode]) {
        // Find windows that need to be added
        let existingWindowIds = getAllWindowIds(from: rootNode)
        let newWindows = windows.filter { !existingWindowIds.contains($0.id) }
        
        // Find windows that need to be removed
        let currentWindowIds = Set(windows.map { $0.id })
        
        // Remove windows that are no longer present
        removeWindowsNotIn(currentWindowIds, from: rootNode)
        
        // Add new windows to appropriate nodes
        for window in newWindows {
            rootNode.addWindow(window)
        }
    }
    
    /// Get all window IDs in the layout tree
    private func getAllWindowIds(from node: LayoutNode) -> Set<UUID> {
        var ids = Set(node.windows.map { $0.id })
        
        for child in node.children {
            ids.formUnion(getAllWindowIds(from: child))
        }
        
        return ids
    }
    
    /// Remove windows that are no longer present
    private func removeWindowsNotIn(_ currentIds: Set<UUID>, from node: LayoutNode) {
        // Remove windows from this node
        node.windows = node.windows.filter { currentIds.contains($0.id) }
        
        // Recursively process children
        for child in node.children {
            removeWindowsNotIn(currentIds, from: child)
        }
    }
    
    /// Calculate layouts for a node and all its children
    private func calculateLayoutsForNode(_ node: LayoutNode) -> [WindowNode: NSRect] {
        var layouts = [WindowNode: NSRect]()
        
        // Apply outer gap to the root node's region
        let region = node.region
        let rect = NSRect(
            x: region.minX + config.outerGap,
            y: region.minY + config.outerGap,
            width: region.width - (2 * config.outerGap),
            height: region.height - (2 * config.outerGap)
        )
        
        // If node has children, split the region and calculate layouts for each child
        if !node.children.isEmpty {
            let childRects = splitRegion(rect, for: node)
            
            for (index, child) in node.children.enumerated() {
                if index < childRects.count {
                    child.region = childRects[index]
                    let childLayouts = calculateLayoutsForNode(child)
                    layouts.merge(childLayouts) { _, new in new }
                }
            }
        }
        // If node has its own windows, calculate layouts based on node's layout type
        else if !node.windows.isEmpty {
            let nodeLayouts = calculateSimpleLayouts(
                windows: node.windows,
                in: rect,
                using: node.layoutType
            )
            layouts.merge(nodeLayouts) { _, new in new }
        }
        
        return layouts
    }
    
    /// Split a region according to node's layout type and split ratio
    private func splitRegion(_ rect: NSRect, for node: LayoutNode) -> [NSRect] {
        guard node.children.count > 0 else { return [rect] }
        
        // Apply correct split based on layout type
        switch node.layoutType {
        case .hstack:
            // Horizontal split (side by side)
            let firstWidth = rect.width * node.splitRatio
            let secondWidth = rect.width - firstWidth - config.windowGap
            
            let firstRect = NSRect(
                x: rect.minX,
                y: rect.minY,
                width: firstWidth,
                height: rect.height
            )
            
            let secondRect = NSRect(
                x: rect.minX + firstWidth + config.windowGap,
                y: rect.minY,
                width: secondWidth,
                height: rect.height
            )
            
            return [firstRect, secondRect]
            
        case .vstack:
            // Vertical split (top and bottom)
            let firstHeight = rect.height * node.splitRatio
            let secondHeight = rect.height - firstHeight - config.windowGap
            
            let firstRect = NSRect(
                x: rect.minX,
                y: rect.minY + secondHeight + config.windowGap,
                width: rect.width,
                height: firstHeight
            )
            
            let secondRect = NSRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: secondHeight
            )
            
            return [firstRect, secondRect]
            
        case .bsp:
            // Binary split - alternate between horizontal and vertical
            let isHorizontal = node.parent?.layoutType != .hstack
            
            if isHorizontal {
                // Similar to hstack split
                let firstWidth = rect.width * node.splitRatio
                let secondWidth = rect.width - firstWidth - config.windowGap
                
                let firstRect = NSRect(
                    x: rect.minX,
                    y: rect.minY,
                    width: firstWidth,
                    height: rect.height
                )
                
                let secondRect = NSRect(
                    x: rect.minX + firstWidth + config.windowGap,
                    y: rect.minY,
                    width: secondWidth,
                    height: rect.height
                )
                
                return [firstRect, secondRect]
            } else {
                // Similar to vstack split
                let firstHeight = rect.height * node.splitRatio
                let secondHeight = rect.height - firstHeight - config.windowGap
                
                let firstRect = NSRect(
                    x: rect.minX,
                    y: rect.minY + secondHeight + config.windowGap,
                    width: rect.width,
                    height: firstHeight
                )
                
                let secondRect = NSRect(
                    x: rect.minX,
                    y: rect.minY,
                    width: rect.width,
                    height: secondHeight
                )
                
                return [firstRect, secondRect]
            }
            
        default:
            // For other types (shouldn't normally have children)
            return [rect]
        }
    }
    
    /// Apply calculated layouts to windows
    private func applyCalculatedLayouts(_ layouts: [WindowNode: NSRect]) {
        for (window, frame) in layouts {
            window.setFrame(frame)
        }
    }
    
    // MARK: - Layout Calculation Methods
    
    /// Calculate binary space partitioning layout
    private func calculateBSPLayout(
        windows: [WindowNode],
        rect: NSRect,
        orientation: Orientation
    ) -> [WindowNode: NSRect] {
        var layouts = [WindowNode: NSRect]()
        
        // If only one window, it gets the whole space
        if windows.count == 1, let window = windows.first {
            layouts[window] = rect
            return layouts
        }
        
        // Split the array in half
        let mid = windows.count / 2
        let firstHalf = Array(windows.prefix(mid))
        let secondHalf = Array(windows.suffix(from: mid))
        
        // Split the rectangle based on orientation
        let (firstRect, secondRect) = splitRectSimple(rect, orientation: orientation)
        
        // Recursively apply BSP with alternating orientation
        let nextOrientation = orientation == .h ? Orientation.v : .h
        
        // Calculate layouts for each half
        let firstLayouts = calculateBSPLayout(
            windows: firstHalf,
            rect: firstRect,
            orientation: nextOrientation
        )
        
        let secondLayouts = calculateBSPLayout(
            windows: secondHalf,
            rect: secondRect,
            orientation: nextOrientation
        )
        
        // Combine layouts
        layouts.merge(firstLayouts) { (_, new) in new }
        layouts.merge(secondLayouts) { (_, new) in new }
        
        return layouts
    }
    
    /// Calculate horizontal stack layout
    private func calculateHStackLayout(
        windows: [WindowNode],
        rect: NSRect
    ) -> [WindowNode: NSRect] {
        var layouts = [WindowNode: NSRect]()
        
        let count = windows.count
        let totalGapWidth = config.windowGap * CGFloat(count - 1)
        let availableWidth = rect.width - totalGapWidth
        let windowWidth = availableWidth / CGFloat(count)
        
        for (index, window) in windows.enumerated() {
            let x = rect.minX + CGFloat(index) * (windowWidth + config.windowGap)
            let frame = NSRect(
                x: x,
                y: rect.minY,
                width: windowWidth,
                height: rect.height
            )
            
            layouts[window] = frame
        }
        
        return layouts
    }
    
    /// Calculate vertical stack layout
    private func calculateVStackLayout(
        windows: [WindowNode],
        rect: NSRect
    ) -> [WindowNode: NSRect] {
        var layouts = [WindowNode: NSRect]()
        
        let count = windows.count
        let totalGapHeight = config.windowGap * CGFloat(count - 1)
        let availableHeight = rect.height - totalGapHeight
        let windowHeight = availableHeight / CGFloat(count)
        
        for (index, window) in windows.enumerated() {
            let y = rect.maxY - windowHeight - CGFloat(index) * (windowHeight + config.windowGap)
            let frame = NSRect(
                x: rect.minX,
                y: y,
                width: rect.width,
                height: windowHeight
            )
            
            layouts[window] = frame
        }
        
        return layouts
    }
    
    /// Calculate z-stack layout (windows on top of each other)
    private func calculateZStackLayout(
        windows: [WindowNode],
        rect: NSRect
    ) -> [WindowNode: NSRect] {
        var layouts = [WindowNode: NSRect]()
        
        // In Z-stack, all windows get the same frame
        for window in windows {
            layouts[window] = rect
        }
        
        // Focus the last window to bring it to front
        if let lastWindow = windows.last {
            DispatchQueue.main.async {
                lastWindow.focus()
            }
        }
        
        return layouts
    }
    
    /// Split a rectangle for simple BSP layout
    private func splitRectSimple(_ rect: NSRect, orientation: Orientation) -> (NSRect, NSRect) {
        switch orientation {
        case .h:
            let width = (rect.width - config.windowGap) / 2
            let firstRect = NSRect(x: rect.minX, y: rect.minY, width: width, height: rect.height)
            let secondRect = NSRect(x: rect.minX + width + config.windowGap, y: rect.minY, width: width, height: rect.height)
            return (firstRect, secondRect)
            
        case .v:
            let height = (rect.height - config.windowGap) / 2
            let firstRect = NSRect(x: rect.minX, y: rect.minY + height + config.windowGap, width: rect.width, height: height)
            let secondRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: height)
            return (firstRect, secondRect)
        }
    }
    
    // MARK: - Window Float Classification
    
    /// Determine if a window should float
    /// Cache the float decision for a window
    private func cacheFloatDecision(for windowNode: WindowNode, shouldFloat: Bool) {
        if let windowID = windowNode.systemWindowID {
            floatDecisionCache.setObject(NSNumber(value: shouldFloat), forKey: NSNumber(value: windowID))
        }
    }
}

// MARK: - Helper Extensions

extension CGFloat {
    /// Clamp a value to a range
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return .minimum(.maximum(self, range.lowerBound), range.upperBound)
    }
}
