//
//  AppDelegate.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties


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
        
        // Initial tiling of active workspace
        if let activeWorkspace = WindowManager.shared.monitorWithMouse?.activeWorkspace {
            activeWorkspace.applyTiling()
        }
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

    /// Setup global hotkeys using a Carbon event tap or similar
    private func setupGlobalHotkeys() {
        // Implementation for global hotkeys would go here
        // This would typically use a framework like HotKey or MASShortcut
        // or implement direct Carbon event handling
    }

    /// Clean up resources before application terminates
    private func cleanupResources() {

        // Stop window observer service
        WindowObserverService.shared.stop()
    }

    /// Initialize window observation system
    @MainActor private func initializeWindowObservation() {
        // Start the unified window observer service
        WindowObserverService.shared.start()

        // Initialize workspace settings but no longer need to set up individual observation
        // since WindowObserverService handles this centrally
        for monitor in WindowManager.shared.monitors {
            for workspace in monitor.workspaces {
                // Set up the workspace for tiling (but not for individual event observation)
//                workspace.setupObservation()
            }
        }

        print("Window observation system initialized")
    }
}
