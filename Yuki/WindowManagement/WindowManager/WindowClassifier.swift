//
//  WindowClassifier.swift
//  Yuki
//
//  Created by Daniel Inama on 7/3/25.
//

import Foundation
import Cocoa

// Missing AX constants
private let kAXSheetSubrole = "AXSheet"
private let kAXActionsAttribute = "AXActions"
private let kAXResizeAction = "AXResize"
private let kAXSystemFloatingWindowSubrole = "AXSystemFloatingWindow"
private let kAXSystemDialogSubrole = "AXSystemDialog"

/// Manages classification of windows as tiable or floating
class WindowClassifier {
    // MARK: - Singleton
    
    /// Shared instance
    static let shared = WindowClassifier()
    
    // MARK: - Properties
    
    /// Collection of rules to determine if windows should float
    private var floatingRules: [WindowClassificationRule] = []
    
    /// Apps whose windows should always float
    private var floatingAppBundleIDs: Set<String> = []
    
    /// Window titles that should always float (partial match)
    private var floatingTitlePatterns: [String] = []
    
    /// Window role/subrole combinations that should float
    private var floatingRoleSubroles: [(role: String, subrole: String?)] = []
    
    /// Extra debug logging enabled
    var debugLoggingEnabled: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        setupDefaultRules()
    }
    
    // MARK: - Setup
    
    /// Setup default classification rules
    private func setupDefaultRules() {
        // Add system dialog apps
        addFloatingAppBundleIDs([
            "com.apple.systempreferences",
            "com.apple.finder.SaveDialog",
            "com.apple.finder.OpenDialog"
        ])
        
        // Add common dialogs by title
        addFloatingTitlePatterns([
            "Preferences",
            "Settings",
            "Properties",
            "Save",
            "Open",
            "Alert",
            "Print",
            "About",
            "Dialog"
        ])
        
        // Add AX roles and subroles that indicate dialogs
        addFloatingRoleSubroles([
            (role: kAXWindowRole as String, subrole: kAXDialogSubrole as String),
            (role: kAXWindowRole as String, subrole: kAXSheetSubrole),
            (role: kAXWindowRole as String, subrole: kAXSystemDialogSubrole),
            (role: kAXWindowRole as String, subrole: kAXSystemFloatingWindowSubrole)
        ])
        
        // Add other common window types that shouldn't be tiled
        addClassificationRule(ModalWindowRule())
        addClassificationRule(MiniaturizedWindowRule())
        addClassificationRule(SmallWindowRule(maxWidth: 400, maxHeight: 400))
        addClassificationRule(UnresizableWindowRule())
    }
    
    // MARK: - Classification API
    
    /// Check if a window should float (not be tiled)
    /// - Parameter window: The window element to check
    /// - Returns: True if the window should float, false if it should be tiled
    func shouldWindowFloat(_ window: AXUIElement) -> Bool {
        // Get window properties for classification
        let title = window.get(Ax.titleAttr) ?? ""
        let role = window.get(Ax.roleAttr) ?? ""
        let subrole = window.get(Ax.subroleAttr)
        
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        
        let app = NSRunningApplication(processIdentifier: pid)
        let bundleID = app?.bundleIdentifier ?? ""
        
        // Check app bundle ID
        if !bundleID.isEmpty && floatingAppBundleIDs.contains(bundleID) {
            logClassification(window, "App bundle ID \(bundleID)", true)
            return true
        }
        
        // Check role/subrole combinations
        for roleSubrole in floatingRoleSubroles {
            if role == roleSubrole.role &&
               (roleSubrole.subrole == nil || subrole == roleSubrole.subrole) {
                logClassification(window, "Role \(role), Subrole \(subrole ?? "nil")", true)
                return true
            }
        }
        
        // Check title patterns
        for pattern in floatingTitlePatterns {
            if title.contains(pattern) {
                logClassification(window, "Title pattern \(pattern)", true)
                return true
            }
        }
        
        // Apply custom rules
        for rule in floatingRules {
            if rule.shouldWindowFloat(window) {
                logClassification(window, rule.description, true)
                return true
            }
        }
        
        // Default to tiling the window
        logClassification(window, "No floating rules matched", false)
        return false
    }
    
    // MARK: - Rule Management
    
    /// Add a custom window classification rule
    /// - Parameter rule: The rule to add
    func addClassificationRule(_ rule: WindowClassificationRule) {
        floatingRules.append(rule)
    }
    
    /// Add app bundle IDs that should always float
    /// - Parameter bundleIDs: Array of bundle identifiers
    func addFloatingAppBundleIDs(_ bundleIDs: [String]) {
        for bundleID in bundleIDs {
            floatingAppBundleIDs.insert(bundleID)
        }
    }
    
    /// Add title patterns that should make windows float
    /// - Parameter patterns: Array of title patterns (partial match)
    func addFloatingTitlePatterns(_ patterns: [String]) {
        floatingTitlePatterns.append(contentsOf: patterns)
    }
    
    /// Add role/subrole combinations that should float
    /// - Parameter roleSubroles: Array of (role, subrole) tuples
    func addFloatingRoleSubroles(_ roleSubroles: [(role: String, subrole: String?)]) {
        floatingRoleSubroles.append(contentsOf: roleSubroles)
    }
    
    /// Remove all custom classification rules
    func clearCustomRules() {
        floatingRules.removeAll()
        setupDefaultRules()
    }
    
    // MARK: - Helpers
    
    /// Log a classification decision if debug logging is enabled
    private func logClassification(_ window: AXUIElement, _ reason: String, _ shouldFloat: Bool) {
        guard debugLoggingEnabled else { return }
        
        let title = window.get(Ax.titleAttr) ?? "Untitled"
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let app = NSRunningApplication(processIdentifier: pid)
        let appName = app?.localizedName ?? "Unknown"
        
        print("Window '\(title)' from app '\(appName)': \(shouldFloat ? "FLOAT" : "TILE") - Reason: \(reason)")
    }
}

// MARK: - Classification Rule Protocol

/// Protocol for window classification rules
protocol WindowClassificationRule {
    /// Determine if a window should float based on this rule
    func shouldWindowFloat(_ window: AXUIElement) -> Bool
    
    /// Description of this rule for logging
    var description: String { get }
}

// MARK: - Common Classification Rules

/// Rule for modal windows (should always float)
class ModalWindowRule: WindowClassificationRule {
    var description: String { "Modal window" }
    
    func shouldWindowFloat(_ window: AXUIElement) -> Bool {
        return window.get(Ax.modalAttr) ?? false
    }
}

/// Rule for minimized windows (should be ignored by tiling)
class MiniaturizedWindowRule: WindowClassificationRule {
    var description: String { "Minimized window" }
    
    func shouldWindowFloat(_ window: AXUIElement) -> Bool {
        return window.get(Ax.minimizedAttr) ?? false
    }
}

/// Rule for small windows (likely dialogs)
class SmallWindowRule: WindowClassificationRule {
    var description: String { "Small window (likely dialog)" }
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    
    init(maxWidth: CGFloat, maxHeight: CGFloat) {
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }
    
    func shouldWindowFloat(_ window: AXUIElement) -> Bool {
        guard let size = window.get(Ax.sizeAttr) else { return false }
        return size.width < maxWidth && size.height < maxHeight
    }
}

/// Rule for windows that cannot be resized
class UnresizableWindowRule: WindowClassificationRule {
    var description: String { "Window cannot be resized" }
    
    func shouldWindowFloat(_ window: AXUIElement) -> Bool {
        // Try to get the resize action - if not available, the window is not resizable
        var actionsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXActionsAttribute as CFString, &actionsRef)
        
        if result == .success, let actions = actionsRef as? [String] {
            return !actions.contains(kAXResizeAction)
        }
        
        return true // Default to floating if we can't determine
    }
}
