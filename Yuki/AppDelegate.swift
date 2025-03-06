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
        // In AppDelegate.swift or early in app initialization
        if !AXIsProcessTrusted() {
            print("WARNING: Accessibility permissions not granted. Window movement will not work.")
            // Show a dialog prompting user to grant permissions
        }
        
        // Initialize the window manager with enhanced settings
        WindowManager.requestAccessibilityPermission()
        initializeWindowObservation()
        // Setup global hotkeys
        setupGlobalHotkeys()
        
        WindowManager.shared.monitorWithMouse?.activeWorkspace?.applyTiling()
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
        //        let windowManager = WindowManager.shared
    }

    /// Initialize window observation system
    @MainActor private func initializeWindowObservation() {

        GlobalObserver.initObserver()
        // Start the window notification center
        _ = WindowNotificationCenter.shared

        // Start the window movement observer
        _ = WindowMoveObserver.shared

        // Make sure each workspace is observing window events
        for monitor in WindowManager.shared.monitors {
            for workspace in monitor.workspaces {
                workspace.setupObservation()
            }
        }

        print("Window observation system initialized")
    }
}
