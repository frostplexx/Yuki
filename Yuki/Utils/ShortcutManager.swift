import Foundation
import HotKey
import Carbon
import Cocoa

/// Manager for global keyboard shortcuts
class ShortcutManager {
    // MARK: - Singleton
    
    /// Shared instance
    static let shared = ShortcutManager()
    
    // MARK: - Properties
    
    /// Active hotkeys
    private var registeredHotkeys: [String: HotKey] = [:]
    
    /// Default keyboard shortcuts
    private let defaultShortcuts: [String: String] = [
        "cycle-layout": "cmd+space",
        "focus-left": "cmd+h",
        "focus-right": "cmd+l",
        "focus-up": "cmd+k",
        "focus-down": "cmd+j",
        "swap-left": "cmd+shift+h",
        "swap-right": "cmd+shift+l",
        "swap-up": "cmd+shift+k",
        "swap-down": "cmd+shift+j",
        "toggle-float": "cmd+t",
        "equalize": "cmd+0",
        "next-workspace": "ctrl+right",
        "prev-workspace": "ctrl+left",
        "workspace-1": "ctrl+1",
        "workspace-2": "ctrl+2",
        "workspace-3": "ctrl+3",
        "workspace-4": "ctrl+4",
        "workspace-5": "ctrl+5",
        "toggle-tiling": "cmd+ctrl+t",
        "reload-config": "cmd+ctrl+r"
    ]
    
    // MARK: - Initialization
    
    private init() {
        // Register for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShortcutsChanged),
            name: NSNotification.Name("com.yuki.ShortcutsChanged"),
            object: nil
        )
        
        // Initial shortcut setup
        setupShortcuts()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        unregisterAllShortcuts()
    }
    
    // MARK: - Shortcut Management
    
    /// Set up all keyboard shortcuts
    func setupShortcuts() {
        // Unregister any existing shortcuts
        unregisterAllShortcuts()
        
        // Get shortcuts from settings or use defaults
        let shortcuts = SettingsManager.shared.getSettings().shortcuts
        
        // Register each shortcut
        for (action, shortcutString) in shortcuts {
            registerShortcut(action: action, shortcutString: shortcutString)
        }
        
        // Register any missing defaults
        for (action, shortcutString) in defaultShortcuts {
            if !shortcuts.keys.contains(action) {
                registerShortcut(action: action, shortcutString: shortcutString)
            }
        }
    }
    
    /// Register a specific shortcut
    private func registerShortcut(action: String, shortcutString: String) {
        // Skip if shortcut string is empty
        guard !shortcutString.isEmpty else { return }
        
        // Parse shortcut string
        guard let keyCombo = keyComboFromString(shortcutString) else {
            print("Failed to parse shortcut: \(shortcutString)")
            return
        }
        
        // Create HotKey
        let hotKey = HotKey(keyCombo: keyCombo)
        
        // Set handler based on action
        hotKey.keyDownHandler = { [weak self] in
            self?.handleAction(action)
        }
        
        // Store in dictionary
        registeredHotkeys[action] = hotKey
    }
    
    /// Unregister all shortcuts
    private func unregisterAllShortcuts() {
        // HotKey automatically unregisters when deallocated
        registeredHotkeys.removeAll()
    }
    
    /// Handle shortcut action
    private func handleAction(_ action: String) {
        let windowManager = WindowManager.shared
        
        switch action {
        case "cycle-layout":
            windowManager.cycleTilingMode()
            
        case "focus-left":
            windowManager.focusWindowInDirection(.left)
            
        case "focus-right":
            windowManager.focusWindowInDirection(.right)
            
        case "focus-up":
            windowManager.focusWindowInDirection(.up)
            
        case "focus-down":
            windowManager.focusWindowInDirection(.down)
            
        case "swap-left":
            windowManager.swapWindowInDirection(.left)
            
        case "swap-right":
            windowManager.swapWindowInDirection(.right)
            
        case "swap-up":
            windowManager.swapWindowInDirection(.up)
            
        case "swap-down":
            windowManager.swapWindowInDirection(.down)
            
        case "toggle-float":
            windowManager.toggleFloatCurrentWindow()
            
        case "equalize":
            windowManager.equalizeWindowSizes()
            
        case "next-workspace":
            if let monitor = windowManager.monitorWithMouse {
                monitor.activateNextWorkspace()
            }
            
        case "prev-workspace":
            if let monitor = windowManager.monitorWithMouse {
                monitor.activatePreviousWorkspace()
            }
            
        case "workspace-1", "workspace-2", "workspace-3", "workspace-4", "workspace-5":
            if let indexStr = action.split(separator: "-").last,
               let index = Int(indexStr),
               let monitor = windowManager.monitorWithMouse {
                if index <= monitor.workspaces.count {
                    monitor.activateWorkspace(at: index - 1) // Convert to 0-based index
                }
            }
            
        case "toggle-tiling":
            // Toggle between tiling and floating for all windows
            if let workspace = windowManager.monitorWithMouse?.activeWorkspace {
                if workspace.tilingEngine.currentLayoutType == .float {
                    workspace.setTilingMode("bsp")
                } else {
                    workspace.setTilingMode("float")
                }
            }
            
        case "reload-config":
            // Reload settings and restart services
            SettingsManager.shared.applyAllSettings()
            
        default:
            print("Unknown action: \(action)")
        }
    }
    
    // MARK: - Parsing Helpers
    
    /// Parse a key combo from a string like "cmd+shift+h"
    private func keyComboFromString(_ string: String) -> KeyCombo? {
        let components = string.lowercased().split(separator: "+").map { String($0) }
        
        // Need at least one component (the key)
        guard let lastComponent = components.last, !lastComponent.isEmpty else {
            return nil
        }
        
        // Convert last component to key code
        let keyString = lastComponent
        guard let keyCode = keyCodeFromString(keyString) else {
            return nil
        }
        
        // Parse modifiers
        var modifiers: NSEvent.ModifierFlags = []
        
        for component in components.dropLast() {
            switch component {
            case "cmd", "command", "⌘":
                modifiers.insert(.command)
            case "ctrl", "control", "⌃":
                modifiers.insert(.control)
            case "alt", "option", "opt", "⌥":
                modifiers.insert(.option)
            case "shift", "⇧":
                modifiers.insert(.shift)
            default:
                print("Unknown modifier: \(component)")
                return nil
            }
        }
        
        return KeyCombo(
            key: Key(carbonKeyCode: UInt32(keyCode))!,
            modifiers: modifiers
        )
    }
    
    /// Convert a key string to key code
    private func keyCodeFromString(_ string: String) -> Int? {
        switch string.lowercased() {
        // Letters
        case "a": return kVK_ANSI_A
        case "b": return kVK_ANSI_B
        case "c": return kVK_ANSI_C
        case "d": return kVK_ANSI_D
        case "e": return kVK_ANSI_E
        case "f": return kVK_ANSI_F
        case "g": return kVK_ANSI_G
        case "h": return kVK_ANSI_H
        case "i": return kVK_ANSI_I
        case "j": return kVK_ANSI_J
        case "k": return kVK_ANSI_K
        case "l": return kVK_ANSI_L
        case "m": return kVK_ANSI_M
        case "n": return kVK_ANSI_N
        case "o": return kVK_ANSI_O
        case "p": return kVK_ANSI_P
        case "q": return kVK_ANSI_Q
        case "r": return kVK_ANSI_R
        case "s": return kVK_ANSI_S
        case "t": return kVK_ANSI_T
        case "u": return kVK_ANSI_U
        case "v": return kVK_ANSI_V
        case "w": return kVK_ANSI_W
        case "x": return kVK_ANSI_X
        case "y": return kVK_ANSI_Y
        case "z": return kVK_ANSI_Z
            
        // Numbers
        case "0": return kVK_ANSI_0
        case "1": return kVK_ANSI_1
        case "2": return kVK_ANSI_2
        case "3": return kVK_ANSI_3
        case "4": return kVK_ANSI_4
        case "5": return kVK_ANSI_5
        case "6": return kVK_ANSI_6
        case "7": return kVK_ANSI_7
        case "8": return kVK_ANSI_8
        case "9": return kVK_ANSI_9
            
        // Arrow keys
        case "left", "←": return kVK_LeftArrow
        case "right", "→": return kVK_RightArrow
        case "up", "↑": return kVK_UpArrow
        case "down", "↓": return kVK_DownArrow
            
        // Special keys
        case "space", " ": return kVK_Space
        case "tab", "⇥": return kVK_Tab
        case "esc", "escape", "⎋": return kVK_Escape
        case "return", "enter", "↩": return kVK_Return
        case "delete", "⌫": return kVK_Delete
            
        // Function keys
        case "f1": return kVK_F1
        case "f2": return kVK_F2
        case "f3": return kVK_F3
        case "f4": return kVK_F4
        case "f5": return kVK_F5
        case "f6": return kVK_F6
        case "f7": return kVK_F7
        case "f8": return kVK_F8
        case "f9": return kVK_F9
        case "f10": return kVK_F10
        case "f11": return kVK_F11
        case "f12": return kVK_F12
            
        default:
            print("Unknown key: \(string)")
            return nil
        }
    }
    
    // MARK: - Settings Change Handling
    
    /// Handle shortcuts changed notification
    @objc private func handleShortcutsChanged(_ notification: Notification) {
        // Reapply shortcuts
        setupShortcuts()
    }
}

// MARK: - Direction Enum

/// Direction for window focus/swap operations
enum Direction {
    case left
    case right
    case up
    case down
}

// MARK: - WindowManager Extensions for Directional Operations

extension WindowManager {
    /// Focus a window in the specified direction
    func focusWindowInDirection(_ direction: Direction) {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        
        // Get all visible windows
        let windows = workspace.getVisibleWindowNodes()
        guard !windows.isEmpty else { return }
        
        // Find currently focused window
        let focusedWindow = windows.first { window in
            window.window.get(Ax.isFocused) ?? false
        }
        
        guard let current = focusedWindow, let currentFrame = current.frame else {
            // If no window is focused, focus the first one
            windows.first?.focus()
            return
        }
        
        // Calculate window center points
        let currentCenter = NSPoint(
            x: currentFrame.midX,
            y: currentFrame.midY
        )
        
        // Find the best window in the specified direction
        var bestWindow: WindowNode?
        var bestScore = CGFloat.infinity
        
        for window in windows where window.id != current.id {
            guard let frame = window.frame else { continue }
            
            let center = NSPoint(
                x: frame.midX,
                y: frame.midY
            )
            
            // Check if window is in the correct direction
            let isInDirection: Bool
            
            switch direction {
            case .left:
                isInDirection = center.x < currentCenter.x
            case .right:
                isInDirection = center.x > currentCenter.x
            case .up:
                isInDirection = center.y > currentCenter.y
            case .down:
                isInDirection = center.y < currentCenter.y
            }
            
            if isInDirection {
                // Calculate score based on distance and alignment
                let distance = hypot(center.x - currentCenter.x, center.y - currentCenter.y)
                let alignmentPenalty: CGFloat
                
                switch direction {
                case .left, .right:
                    // Penalize vertical misalignment for horizontal movement
                    alignmentPenalty = abs(center.y - currentCenter.y) * 2
                case .up, .down:
                    // Penalize horizontal misalignment for vertical movement
                    alignmentPenalty = abs(center.x - currentCenter.x) * 2
                }
                
                let score = distance + alignmentPenalty
                
                if score < bestScore {
                    bestScore = score
                    bestWindow = window
                }
            }
        }
        
        // Focus the best window, or wrap around if none found
        if let window = bestWindow {
            window.focus()
        } else {
            // Wrap around to the opposite edge
            let oppositeEdgeWindows: [WindowNode]
            
            switch direction {
            case .left:
                // Find rightmost windows
                oppositeEdgeWindows = windows.sorted { $0.frame?.maxX ?? 0 > $1.frame?.maxX ?? 0 }
            case .right:
                // Find leftmost windows
                oppositeEdgeWindows = windows.sorted { $0.frame?.minX ?? 0 < $1.frame?.minX ?? 0 }
            case .up:
                // Find bottommost windows
                oppositeEdgeWindows = windows.sorted { $0.frame?.minY ?? 0 < $1.frame?.minY ?? 0 }
            case .down:
                // Find topmost windows
                oppositeEdgeWindows = windows.sorted { $0.frame?.maxY ?? 0 > $1.frame?.maxY ?? 0 }
            }
            
            if let bestOpposite = oppositeEdgeWindows.first(where: { $0.id != current.id }) {
                bestOpposite.focus()
            }
        }
    }
    
    /// Swap the current window with another in the specified direction
    func swapWindowInDirection(_ direction: Direction) {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        
        // Skip if in float mode
        if workspace.tilingEngine.currentLayoutType == .float {
            return
        }
        
        // Get all visible windows
        let windows = workspace.getVisibleWindowNodes()
        guard windows.count > 1 else { return }
        
        // Find currently focused window
        let focusedWindow = windows.first { window in
            window.window.get(Ax.isFocused) ?? false
        }
        
        guard let current = focusedWindow, let currentFrame = current.frame else {
            return
        }
        
        // Use the same logic as focus to find the target window
        let currentCenter = NSPoint(
            x: currentFrame.midX,
            y: currentFrame.midY
        )
        
        // Find the best window in the specified direction
        var bestWindow: WindowNode?
        var bestScore = CGFloat.infinity
        
        for window in windows where window.id != current.id {
            guard let frame = window.frame else { continue }
            
            let center = NSPoint(
                x: frame.midX,
                y: frame.midY
            )
            
            // Check if window is in the correct direction
            let isInDirection: Bool
            
            switch direction {
            case .left:
                isInDirection = center.x < currentCenter.x
            case .right:
                isInDirection = center.x > currentCenter.x
            case .up:
                isInDirection = center.y > currentCenter.y
            case .down:
                isInDirection = center.y < currentCenter.y
            }
            
            if isInDirection {
                // Calculate score based on distance and alignment
                let distance = hypot(center.x - currentCenter.x, center.y - currentCenter.y)
                let alignmentPenalty: CGFloat
                
                switch direction {
                case .left, .right:
                    alignmentPenalty = abs(center.y - currentCenter.y) * 2
                case .up, .down:
                    alignmentPenalty = abs(center.x - currentCenter.x) * 2
                }
                
                let score = distance + alignmentPenalty
                
                if score < bestScore {
                    bestScore = score
                    bestWindow = window
                }
            }
        }
        
        // Swap with the best window
        if let target = bestWindow, let targetFrame = target.frame {
            // For BSP layout, we need to focus a bit differently to maintain tree structure
            if workspace.tilingEngine.currentLayoutType == .bsp {
                // Simply apply tiling after swapping
                current.setFrame(targetFrame)
                target.setFrame(currentFrame)
                workspace.applyTiling()
            } else {
                // Simple frame swap
                current.setFrame(targetFrame)
                target.setFrame(currentFrame)
                
                // Keep focus on original window
                current.focus()
            }
        }
    }
    
    /// Toggle floating state of current window
    func toggleFloatCurrentWindow() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        
        // Find focused window
        let windows = workspace.getAllWindowNodes()
        let focusedWindow = windows.first { window in
            window.window.get(Ax.isFocused) ?? false
        }
        
        guard let window = focusedWindow else { return }
        
        // Toggle floating state
        window.toggleFloating()
        
        // Apply tiling to update layout
        workspace.applyTiling()
    }
    
    /// Equalize window sizes
    func equalizeWindowSizes() {
        guard let workspace = monitorWithMouse?.activeWorkspace else { return }
        
        // Skip if in float mode
        if workspace.tilingEngine.currentLayoutType == .float {
            return
        }
        
        // For binary space partitioning, rebuild the tree with equal splits
        if workspace.tilingEngine.currentLayoutType == .bsp {
            workspace.tilingEngine.rebuildWithEqualSplits()
        }
        
        // Apply tiling to update layout
        workspace.applyTiling()
    }
}

// Add a method to TilingEngine for rebuilding with equal splits
extension TilingEngine {
    /// Rebuild the layout tree with equal splits
    func rebuildWithEqualSplits() {
        // This is a simplified version - actual implementation would need to preserve tree structure
        if let workspace = workspace {
            let windows = workspace.getVisibleWindowNodes()
            syncQueue.sync {
                rootNode = LayoutNode(layoutType: currentLayoutType)
                rootNode.windows = windows
                if windows.count > 1 && currentLayoutType != .zstack && currentLayoutType != .float {
                    createEqualSplits(for: rootNode)
                }
            }
        }
    }
    
    /// Create equal splits for a node
    private func createEqualSplits(for node: LayoutNode) {
        // Always use 0.5 as the split ratio for equal splits
        let (first, second) = node.split(ratio: 0.5, firstType: node.layoutType, secondType: node.layoutType)
        
        // Recursively create equal splits if needed
        if first.windows.count > 1 && first.layoutType != .zstack && first.layoutType != .float {
            createEqualSplits(for: first)
        }
        
        if second.windows.count > 1 && second.layoutType != .zstack && second.layoutType != .float {
            createEqualSplits(for: second)
        }
    }
}
