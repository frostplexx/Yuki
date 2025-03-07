//
//  WindowNotificationCenter.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import Foundation
import Cocoa

/// Notification names for window events
//extension Notification.Name {
//    static let windowMoved = Notification.Name("com.yuki.WindowMoved")
//    static let windowResized = Notification.Name("com.yuki.WindowResized")
//    static let windowCreated = Notification.Name("com.yuki.WindowCreated")
//    static let windowRemoved = Notification.Name("com.yuki.WindowRemoved")
//    static let workspaceActivated = Notification.Name("com.yuki.WorkspaceActivated")
//    static let tilingModeChanged = Notification.Name("com.yuki.TilingModeChanged")
//}

/// Central class for posting and receiving window event notifications
class WindowNotificationCenter {
    /// Shared instance (singleton)
    static let shared = WindowNotificationCenter()
    
    /// Internal notification center
    private let center = NotificationCenter.default
    
    private init() {
        // Register for system window events
        registerForWindowEvents()
    }
    
    // MARK: - Registration for System Events
    
    /// Register for system-level window events
    private func registerForWindowEvents() {
        // Register for accessibility notification callbacks
        // This would be done through AXObserver in a real implementation
        
        // Register for system window notifications through app workspace
        let nc = NSWorkspace.shared.notificationCenter
        
        nc.addObserver(self, selector: #selector(handleAppActivated(_:)),
                        name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        nc.addObserver(self, selector: #selector(handleAppTerminated(_:)),
                        name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        
        nc.addObserver(self, selector: #selector(handleSpaceChanged(_:)),
                        name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }
    
    // MARK: - System Event Handlers
    
    @objc private func handleAppActivated(_ notification: Notification) {
        // When an app is activated, we need to refresh window information
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            WindowManager.shared.refreshWindowsList()
        }
    }
    
    @objc private func handleAppTerminated(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            WindowManager.shared.removeWindowsForApp(app.processIdentifier)
        }
    }
    
    @objc private func handleSpaceChanged(_ notification: Notification) {
        // When spaces change, refresh windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WindowManager.shared.refreshWindowsList()
        }
    }
    
    // MARK: - Add/Remove Observers
    
    /// Add an observer for a specific notification
    func addObserver(_ observer: Any, selector: Selector, name: Notification.Name, object: Any? = nil) {
        center.addObserver(observer, selector: selector, name: name, object: object)
    }
    
    /// Remove an observer
    func removeObserver(_ observer: Any) {
        center.removeObserver(observer)
    }
    
    // MARK: - Post Notifications
    
    /// Post a window moved notification
    func postWindowMoved(_ windowId: Int) {
        center.post(name: .windowMoved, object: nil, userInfo: ["windowId": windowId])
        print("Posted window moved notification for window \(windowId)")
    }
    
    /// Post a window resized notification
    func postWindowResized(_ windowId: Int) {
        center.post(name: .windowResized, object: nil, userInfo: ["windowId": windowId])
        print("Posted window resized notification for window \(windowId)")
    }
    
    /// Post a window created notification
    func postWindowCreated(_ windowId: Int) {
        center.post(name: .windowCreated, object: nil, userInfo: ["windowId": windowId])
        print("Posted window created notification for window \(windowId)")
    }
    
    /// Post a window removed notification
    func postWindowRemoved(_ windowId: Int) {
        center.post(name: .windowRemoved, object: nil, userInfo: ["windowId": windowId])
        print("Posted window removed notification for window \(windowId)")
    }
    
    /// Post a workspace activated notification
    func postWorkspaceActivated(_ workspace: WorkspaceNode) {
        center.post(name: .workspaceActivated, object: workspace)
    }
    
    /// Post a tiling mode changed notification
    func postTilingModeChanged(_ workspace: WorkspaceNode) {
        center.post(name: .tilingModeChanged, object: workspace)
    }
}
