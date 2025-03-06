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
        WindowManager.requestAccessibilityPermission()
        GlobalObserver.initObserver()
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
        WindowManager.shared.printDebugInfo()
        
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        print("Application resigned active state")
    }
    
    // MARK: - Setup Methods
    
    /// Setup enhanced window manager initialization
    
    /// Setup global hotkeys using a Carbon event tap or similar
    private func setupGlobalHotkeys() {
        // Implementation for global hotkeys would go here
        // This would typically use a framework like HotKey or MASShortcut
        // or implement direct Carbon event handling
    }
    
    /// Clean up resources before application terminates
    private func cleanupResources() {
        // Stop refresh timer
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        // Clean up window manager resources
        let windowManager = WindowManager.shared
    }
}

