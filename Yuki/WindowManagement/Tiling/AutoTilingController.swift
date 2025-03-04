//
//  AutoTilingController.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa

/// Controller class that handles automatic window tiling
class AutoTilingController {
    // MARK: - Properties
    
    /// The window manager instance
    private weak var windowManager: WindowManager?
    
    /// Whether auto-tiling is enabled
    private var autoTilingEnabled: Bool = true
    
    /// Timer for delayed tiling after window changes
    private var tilingTimer: Timer?
    
    // MARK: - Initialization
    
    /// Initialize with a window manager
    /// - Parameter windowManager: The window manager to use
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        
        // Load auto-tiling preference
        loadPreferences()
        
        // Set up notifications for window changes
        setupNotifications()
    }
    
    // MARK: - Preferences
    
    /// Load auto-tiling preferences
    private func loadPreferences() {
        autoTilingEnabled = UserDefaults.standard.bool(forKey: "YukiAutoTilingEnabled")
        
        // Default to enabled if not set
        if !UserDefaults.standard.contains(key: "YukiAutoTilingEnabled") {
            autoTilingEnabled = true
            UserDefaults.standard.set(true, forKey: "YukiAutoTilingEnabled")
        }
    }
    
    /// Set whether auto-tiling is enabled
    /// - Parameter enabled: Whether to enable auto-tiling
    func setAutoTilingEnabled(_ enabled: Bool) {
        autoTilingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "YukiAutoTilingEnabled")
        
        if enabled {
            // Apply tiling immediately when enabled
            applyTilingWithDelay()
        }
    }
    
    /// Returns whether auto-tiling is enabled
    /// - Returns: Auto-tiling enabled state
    func isAutoTilingEnabled() -> Bool {
        return autoTilingEnabled
    }
    
    /// Toggle auto-tiling on/off
    /// - Returns: The new auto-tiling state
    @discardableResult
    func toggleAutoTiling() -> Bool {
        setAutoTilingEnabled(!autoTilingEnabled)
        return autoTilingEnabled
    }
    
    // MARK: - Notifications
    
    /// Set up notifications for window changes
    private func setupNotifications() {
        // Listen for window changes
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // Window events
        notificationCenter.addObserver(
            self,
            selector: #selector(handleWindowChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Additional notification for window resizing or moving
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWindowChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }
    
    /// Handle window change notifications
    @objc private func handleWindowChange() {
        guard autoTilingEnabled else { return }
        
        // Apply tiling with a delay to avoid excessive tiling during window manipulations
        applyTilingWithDelay()
    }
    
    // MARK: - Tiling Operations
    
    /// Apply tiling with a delay to avoid excessive tiling operations
    private func applyTilingWithDelay() {
        // Cancel any existing timer
        tilingTimer?.invalidate()
        
        // Create a new timer with a short delay
        tilingTimer = Timer.scheduledTimer(
            timeInterval: 0.5, // Half-second delay
            target: self,
            selector: #selector(applyTilingNow),
            userInfo: nil,
            repeats: false
        )
    }
    
    /// Apply tiling immediately
    @objc private func applyTilingNow() {
        windowManager?.applyCurrentTiling()
    }
    
    /// Apply tiling after window refresh
    func applyTilingAfterRefresh() {
        guard autoTilingEnabled else { return }
        
        // Refresh windows first
        windowManager?.refreshWindows()
        
        // Then apply tiling
        windowManager?.applyCurrentTiling()
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    /// Check if a key exists in user defaults
    /// - Parameter key: The key to check
    /// - Returns: Whether the key exists
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

// MARK: - WindowManager Extension

extension WindowManager {
    /// The auto-tiling controller instance
    private struct AssociatedKeys {
        static var autoTilingController = "autoTilingController"
    }
    
    /// Get the auto-tiling controller, creating it if needed
    var autoTilingController: AutoTilingController {
        // Check if we already have an auto-tiling controller
        if let controller = objc_getAssociatedObject(self, &AssociatedKeys.autoTilingController) as? AutoTilingController {
            return controller
        }
        
        // Create a new controller
        let controller = AutoTilingController(windowManager: self)
        objc_setAssociatedObject(
            self,
            &AssociatedKeys.autoTilingController,
            controller,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        return controller
    }
    
    /// Initialize auto-tiling
    func initializeAutoTiling() {
        // This will create the controller if needed
        let _ = autoTilingController
        
        // Apply initial tiling if enabled
        if autoTilingController.isAutoTilingEnabled() {
            applyCurrentTiling()
        }
    }
    
    /// Toggle auto-tiling
    /// - Returns: New auto-tiling state
    @discardableResult
    func toggleAutoTiling() -> Bool {
        return autoTilingController.toggleAutoTiling()
    }
}
