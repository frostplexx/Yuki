//
//  AppDelegate.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup global hotkeys or other initialization
        setupGlobalHotkeys()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up any resources before app terminates
        print("Application will terminate")
    }
    
    // Setup global hotkeys using a Carbon event tap or similar
    private func setupGlobalHotkeys() {
        // Implementation for global hotkeys would go here
        // This would typically use a framework like HotKey or MASShortcut
        // or implement direct Carbon event handling
    }
    
    // Handle NSEvents at the application level if needed
    func applicationDidBecomeActive(_ notification: Notification) {
        print("Application became active")
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        print("Application resigned active state")
    }
}
