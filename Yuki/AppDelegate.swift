//
//  AppDelegate.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import SwiftUI
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    
    // Keep reference to shortcut manager
    private var shortcutManager: ShortcutManager?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // In AppDelegate.swift or early in app initialization
        if !AXIsProcessTrusted() {
            print("WARNING: Accessibility permissions not granted. Window movement will not work.")
            // Show a dialog prompting user to grant permissions
            showAccessibilityPermissionsAlert()
        }
        
        // Request accessibility permission
        WindowManager.requestAccessibilityPermission()
        
        // Initialize window manager
        initializeWindowManagement()
        
        // Setup keyboard shortcuts
        setupGlobalHotkeys()
        
        // Load and apply settings
//        SettingsManager.shared.applyAllSettings()
        
        // Initial tiling of active workspace
        if let activeWorkspace = WindowManager.shared.monitorWithMouse?.activeWorkspace {
            activeWorkspace.applyTiling()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save settings before termination
        SettingsManager.shared.captureCurrentWorkspaces()
        
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

    /// Setup global hotkeys using HotKey library
    private func setupGlobalHotkeys() {
        // Initialize the shortcut manager
        shortcutManager = ShortcutManager.shared
        
        // Register notification observers for updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: NSNotification.Name("com.yuki.SettingsChanged"),
            object: nil
        )
    }
    
    /// Handle settings changes
    @objc private func handleSettingsChanged(_ notification: Notification) {
        // Apply updated settings
        SettingsManager.shared.applyAllSettings()
    }

    /// Clean up resources before application terminates
    private func cleanupResources() {
        // Stop window observer service
        WindowObserverService.shared.stop()
        
        // Release shortcut manager
        shortcutManager = nil
    }

    /// Initialize window management system
    @MainActor private func initializeWindowManagement() {
        // Start the unified window observer service
        WindowObserverService.shared.start()

        // Initialize workspace settings but no longer need to set up individual observation
        // since WindowObserverService handles this centrally
        for monitor in WindowManager.shared.monitors {
            for workspace in monitor.workspaces {
                // Set up the workspace for tiling (but not for individual event observation)
                // workspace.setupObservation()
            }
        }

        print("Window management system initialized")
    }
    
    /// Show an alert if accessibility permissions aren't granted
    private func showAccessibilityPermissionsAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "Yuki needs accessibility permissions to manage your windows. Without these permissions, window tiling will not work correctly."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
