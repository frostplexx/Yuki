//
//  AppDelegate.swift
//  Yuki
//
//  Created by Claude AI on 6/3/25.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    
    /// Timer for periodic window refresh
    private var refreshTimer: Timer?
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the window manager with enhanced settings
        setupEnhancedWindowManager()
        
        // Setup global hotkeys
        setupGlobalHotkeys()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up any resources before app terminates
        cleanupResources()
        print("Application will terminate")
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        print("Application became active")
        
        // Refresh windows when application becomes active
        refreshWindows()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        print("Application resigned active state")
    }
    
    // MARK: - Setup Methods
    
    /// Setup enhanced window manager initialization
    func setupEnhancedWindowManager() {
        // Get window manager
        let windowManager = WindowManagerProvider.shared
        
        // Request accessibility permissions first
        AccessibilityService.shared.requestPermission()
        
        // Perform enhanced initialization
        windowManager.enhancedInitialization()
        
        // Set up a periodic refresh timer as a fallback
        startPeriodicWindowRefresh()
    }
    
    /// Setup global hotkeys using a Carbon event tap or similar
    private func setupGlobalHotkeys() {
        // Implementation for global hotkeys would go here
        // This would typically use a framework like HotKey or MASShortcut
        // or implement direct Carbon event handling
    }
    
    /// Start a periodic window refresh timer
    private func startPeriodicWindowRefresh() {
        // Stop existing timer if any
        refreshTimer?.invalidate()
        
        // Create a timer that runs every 5 seconds to catch any windows that were missed
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshWindows()
        }
    }
    
    /// Refresh windows if needed
    private func refreshWindows() {
        let windowManager = WindowManagerProvider.shared
        
        // Check if window manager should refresh (only if app is active)
        if NSApp.isActive {
            // Get window observer and force refresh
            windowManager.windowObserver?.forceWindowRefresh()
            
            // Reapply tiling if not in float mode
            if TilingEngine.shared.currentMode != .float {
                windowManager.applyCurrentTilingWithPinning()
            }
        }
    }
    
    /// Clean up resources before application terminates
    private func cleanupResources() {
        // Stop refresh timer
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        // Clean up window manager resources
        let windowManager = WindowManagerProvider.shared
        windowManager.windowObserver?.stopObserving()
    }
}

