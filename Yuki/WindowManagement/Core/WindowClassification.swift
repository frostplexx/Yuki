// TilingEngine+WindowClassification.swift
// Window classification for automatic floating decisions

import Foundation
import Cocoa

extension TilingEngine {
    // MARK: - Window Classification
    
    /// Rules for determining if a window should float
    struct FloatRule {
        enum RuleType {
            case bundleID
            case subrole
            case windowTitle
            case size
            case isModal
        }
        
        let type: RuleType
        let value: Any
        let description: String
        let shouldFloat: Bool  // Allows for whitelist/blacklist approach
        
        // Helper to create bundle ID rule
        static func app(_ bundleID: String, description: String = "", shouldFloat: Bool = true) -> FloatRule {
            return FloatRule(type: .bundleID, value: bundleID, description: description, shouldFloat: shouldFloat)
        }
        
        // Helper to create subrole rule
        static func subrole(_ subrole: String, description: String = "", shouldFloat: Bool = true) -> FloatRule {
            return FloatRule(type: .subrole, value: subrole, description: description, shouldFloat: shouldFloat)
        }
        
        // Helper to create title keyword rule
        static func titleContains(_ keyword: String, description: String = "", shouldFloat: Bool = true) -> FloatRule {
            return FloatRule(type: .windowTitle, value: keyword, description: description, shouldFloat: shouldFloat)
        }
    }
    
    /// Default float rules
    private var defaultFloatRules: [FloatRule] {
        return [
            // App bundle IDs that should always float
            .app("com.apple.systempreferences", description: "System Preferences"),
            .app("com.apple.finder.SaveDialog", description: "Save Dialog"),
            .app("com.apple.finder.OpenDialog", description: "Open Dialog"),
            .app("com.apple.PreferencePane", description: "Preference Pane"),
            .app("com.apple.ColorSyncUtility", description: "ColorSync Utility"),
            .app("com.apple.print.PrintCenter", description: "Print Center"),
            
            // Window subroles that should float
            .subrole("AXDialog", description: "Dialog windows"),
            .subrole("AXSheet", description: "Sheet windows"),
            .subrole("AXSystemDialog", description: "System Dialog"),
            .subrole("AXFloatingWindow", description: "Floating windows"),
            
            // Title keywords that suggest floating windows
            .titleContains("Preferences"),
            .titleContains("Settings"),
            .titleContains("Options"),
            .titleContains("Properties"),
            .titleContains("Dialog"),
            .titleContains("Alert"),
            .titleContains("Inspector"),
            .titleContains("Navigator"),
            .titleContains("Quick Help"),
            .titleContains("Library"),
            .titleContains("Find"),
            .titleContains("Search"),
            .titleContains("Go To")
        ]
    }
    
    
    /// Quickly determine if a window should float
    func shouldWindowFloat(_ windowNode: WindowNode) -> Bool {
        // Check explicit user preference first
        if windowNode.isFloating {
            return true
        }
        
        // Check minimized state
        if windowNode.isMinimized {
            return true
        }
        
        // Try to use cached decision
        let window = windowNode.window
        var windowID: CGWindowID = 0
        if _AXUIElementGetWindow(window, &windowID) == .success {
            let cacheKey = NSNumber(value: windowID)
            if let cachedDecision = floatDecisionCache.object(forKey: cacheKey) {
                return cachedDecision.boolValue
            }
        }
        
        // Now do the more expensive checks
        let shouldFloat = evaluateWindowFloatRules(window: window, windowNode: windowNode)
        
        // Cache the decision
        if windowID != 0 {
            floatDecisionCache.setObject(NSNumber(value: shouldFloat), forKey: NSNumber(value: windowID))
        }
        
        return shouldFloat
    }
    
    /// Apply float rules to determine if a window should float
    private func evaluateWindowFloatRules(window: AXUIElement, windowNode: WindowNode) -> Bool {
        // Get necessary window attributes (only when needed)
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        
        let app = NSRunningApplication(processIdentifier: pid)
        let bundleID = app?.bundleIdentifier ?? ""
        
        // Check bundle ID rules (fast check)
        for rule in defaultFloatRules where rule.type == .bundleID {
            if let ruleBundleID = rule.value as? String, bundleID == ruleBundleID {
                return rule.shouldFloat
            }
        }
        
        // Check subrole (moderately expensive)
        if let subrole = window.get(Ax.subroleAttr) {
            for rule in defaultFloatRules where rule.type == .subrole {
                if let ruleSubrole = rule.value as? String, subrole == ruleSubrole {
                    return rule.shouldFloat
                }
            }
        }
        
        // Check for modal windows
        if window.get(Ax.modalAttr) == true {
            return true
        }
        
        // Check for size - small windows likely dialogs (fast check)
        if let size = window.get(Ax.sizeAttr) {
            // Small windows are likely dialogs
            if size.width < 300 && size.height < 300 {
                return true
            }
            
            // Short wide windows are likely autocomplete or notifications
            if size.height < 150 && size.width > 300 {
                return true
            }
        }
        
        // Title check (more expensive, only do if necessary)
        if let title = window.get(Ax.titleAttr) {
            for rule in defaultFloatRules where rule.type == .windowTitle {
                if let keyword = rule.value as? String, title.localizedCaseInsensitiveContains(keyword) {
                    return rule.shouldFloat
                }
            }
            
            // Special case for Xcode - tile main editor windows
            if bundleID == "com.apple.dt.Xcode" {
                // Main editor windows often have file extensions in title
                if title.contains(".swift") ||
                   title.contains(".h") ||
                   title.contains(".m") ||
                   title.contains(".c") ||
                   title.contains(".cpp") {
                    return false // Don't float these windows
                }
            }
        }
        
        // Default to tiling if no rules matched
        return false
    }
    
    /// Clear float decision cache (call when window state changes)
    func clearFloatDecisionCache() {
        floatDecisionCache.removeAllObjects()
    }
    
    /// Clear float decision for specific window
    func clearFloatDecision(forWindowID windowID: CGWindowID) {
        floatDecisionCache.removeObject(forKey: NSNumber(value: windowID))
    }
}
