import sys_types
import AppKit
extension TilingEngine {
    // MARK: - Window Classification
    
    /// Check if a window should float (not be tiled)
    func shouldWindowFloat(_ windowNode: WindowNode) -> Bool {
        // Skip window if already set to float
        if windowNode.isFloating {
            return true
        }
        
        let window = windowNode.window
        
        // 1. Check for minimized state
        if windowNode.isMinimized {
            return true
        }
        
        // 2. Get window app info first (fast check)
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        
        // Performance optimization: Use a local cache for bundleIDs to avoid repeated lookups
        let bundleID: String
        let appName: String
        
        // Bundle ID cache could be added to TilingEngine class if needed
        if let app = NSRunningApplication(processIdentifier: pid) {
            bundleID = app.bundleIdentifier ?? ""
            appName = app.localizedName ?? "Unknown"
        } else {
            bundleID = ""
            appName = "Unknown"
        }
        
        
        // 5. Always float certain apps - moved up for early return
        let alwaysFloatApps = [
            "com.apple.systempreferences",
            "com.apple.finder.SaveDialog",
            "com.apple.finder.OpenDialog",
            "com.apple.PreferencePane",
            "com.apple.ColorSyncUtility",
            "com.apple.print.PrintCenter"
        ]
        
        if alwaysFloatApps.contains(bundleID) {
            return true
        }
        
        // 6. Get window subrole - more efficient to check this before getting title
        let subrole = window.get(Ax.subroleAttr) ?? ""
        
        // 8. Check subrole - float special window types
        if subrole != "" && subrole != kAXStandardWindowSubrole as String {
            return true
        }
        
        // 9. Check for modal windows - another early check
        if window.get(Ax.modalAttr) ?? false {
            return true
        }
        
        // 10. Check for size - small windows likely dialogs
        if let size = window.get(Ax.sizeAttr) {
            // Small windows are likely dialogs
            if size.width < 300 && size.height < 300 {
                return true
            }
            
            // Short wide windows are likely autocomplete
            if size.height < 150 && size.width > 300 {
                return true
            }
        }
        
        // 4. Special case for Xcode - tile main editor windows
        if bundleID == "com.apple.dt.Xcode" {
            // Get window title - do this only when needed
            let title = window.get(Ax.titleAttr) ?? ""
            
            // Main editor windows often have file extensions in title
            if title.contains(".swift") ||
               title.contains(".h") ||
               title.contains(".m") ||
               title.contains(".c") ||
               title.contains(".cpp") {
                return false // Don't float these windows
            }
        }
        
        // 7. Check title keywords for utility windows - only get title when needed
        let title = window.get(Ax.titleAttr) ?? ""
        
        let floatingKeywords = [
            "Preferences", "Settings", "Options",
            "Properties", "Dialog", "Alert",
            "Inspector", "Navigator", "Quick Help",
            "Library", "Find", "Search", "Go To"
        ]
        
        for keyword in floatingKeywords {
            if title.localizedCaseInsensitiveContains(keyword) {
                return true
            }
        }
        
        // Default to tile the window (changed default behavior)
        return false
    }
    
    // Print window details for debugging
    func printWindowDetails(_ windowNode: WindowNode, shouldFloat: Bool) {
        let window = windowNode.window
        let title = window.get(Ax.titleAttr) ?? "Untitled"
        let role = window.get(Ax.roleAttr) ?? "Unknown role"
        let subrole = window.get(Ax.subroleAttr) ?? "No subrole"
        
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let app = NSRunningApplication(processIdentifier: pid)
        let appName = app?.localizedName ?? "Unknown"
        let bundleID = app?.bundleIdentifier ?? "Unknown"
        
        let size = windowNode.size ?? NSSize(width: 0, height: 0)
        
        let status = shouldFloat ? "🟢 FLOAT" : "🔴 TILE"
        
        print("\(status) Window: \"\(title)\" from \(appName) (\(bundleID))")
        print("  Role: \(role), Subrole: \(subrole), Size: \(Int(size.width))×\(Int(size.height))")
        
        // Check if window is resizable
        var actionsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, "AXActions" as CFString, &actionsRef)
        var isResizable = false
        
        if result == .success, let actions = actionsRef as? [String] {
            isResizable = actions.contains("AXResize")
        }
        
        print("  Resizable: \(isResizable), Minimized: \(windowNode.isMinimized), Explicitly Floating: \(windowNode.isFloating)")
    }
}
