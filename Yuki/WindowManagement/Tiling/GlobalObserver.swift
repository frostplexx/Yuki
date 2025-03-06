//
//  GlobalObserver.swift
//  Yuki
//

import AppKit
import Cocoa

let lockScreenAppBundleId = "com.apple.loginwindow"

class GlobalObserver {
    // Keep track of apps we're observing for window creation
    private static var observedApps: [pid_t: AXObserver] = [:]
    
    private static func onNotif(_ notification: Notification) {
        check(Thread.isMainThread)
        if (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == lockScreenAppBundleId {
            return
        }
        
        let notifName = notification.name.rawValue
//        print("Got Notification: \(notifName)")
        
        // For application launch, register for window creation notifications
        if notification.name == NSWorkspace.didLaunchApplicationNotification,
           let launchedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            registerForWindowCreationNotifications(for: launchedApp.processIdentifier)
        }
        // For application activation (dock or cmd+tab), switch to the appropriate workspace
        else if notification.name == NSWorkspace.didActivateApplicationNotification,
                let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            handleAppActivation(activatedApp)
        }
        // For other notifications, refresh the window list
        else {
            WindowManager.shared.refreshWindowsList()
        }
    }
    
    private static func onHideApp(_ notification: Notification) {
        check(Thread.isMainThread)
        if let hiddenApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            WindowManager.shared.removeWindowsForApp(hiddenApp.processIdentifier)
        }
    }
    
    //TODO: Move some of this to a separate file or something
    
    // Handle application activation (dock click, cmd+tab, etc.)
    private static func handleAppActivation(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        
        // Try to find a workspace containing a window from this app
        let workspaces = findWorkspacesContainingApp(pid)
        if let targetWorkspace = workspaces.first {
            // Only switch workspaces if needed
            if targetWorkspace.monitor.activeWorkspace?.id != targetWorkspace.id {
                print("App activation detected (\(app.localizedName ?? "Unknown")), activating workspace: \(targetWorkspace.title ?? "Unknown")")
                DispatchQueue.main.async {
                    targetWorkspace.activate()
                }
            }
        }
        
        // Always refresh window list to ensure proper window state
        WindowManager.shared.refreshWindowsList()
    }
    
    // Find all workspaces that contain windows from the given application
    private static func findWorkspacesContainingApp(_ pid: pid_t) -> [WorkspaceNode] {
        var result: [WorkspaceNode] = []
        
        for monitor in WindowManager.shared.monitors {
            for workspace in monitor.workspaces {
                // Check if this workspace has any windows from this application
                let windowNodes = workspace.getAllWindowNodes()
                let hasAppWindow = windowNodes.contains { node in
                    WindowManager.shared.getPID(for: node.window) == pid
                }
                
                if hasAppWindow {
                    result.append(workspace)
                }
            }
        }
        
        return result
    }
    
    // Register for AX notifications when windows are created in an application
    private static func registerForWindowCreationNotifications(for pid: pid_t) {
//        print("Registering for window creation notifications for app with PID: \(pid)")
        
        // Create AX observer
        var observer: AXObserver?
        let error = AXObserverCreate(pid, axNotificationCallback, &observer)
        
        guard error == .success, let observer = observer else {
            print("Failed to create AX observer for application with PID \(pid): \(error)")
            return
        }
        
        // Get the application element
        let appElement = AXUIElementCreateApplication(pid)
        
        // Register for window creation and showing notifications
        AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, nil)
        AXObserverAddNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString, nil)
        AXObserverAddNotification(observer, appElement, kAXApplicationActivatedNotification as CFString, nil)
        
        // Add to CFRunLoop to receive notifications
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        
        // Store the observer
        observedApps[pid] = observer
        
        // Additionally, check for any windows that already exist
        WindowManager.shared.discoverAndAssignWindows()
    }
    
    // Callback for AX notifications
    private static let axNotificationCallback: AXObserverCallback = { observer, element, notification, userData in
        DispatchQueue.main.async {
//            print("AX Notification received: \(notification as String)")
            
            // If a window was created or shown, refresh the window list
            if notification as String == kAXWindowCreatedNotification ||
                notification as String == kAXFocusedWindowChangedNotification ||
                notification as String == kAXApplicationActivatedNotification {
                WindowManager.shared.discoverAndAssignWindows()
                
                // If this is a window creation notification, try to assign it to the right workspace
                if notification as String == kAXWindowCreatedNotification {
                    var pid: pid_t = 0
                    AXUIElementGetPid(element, &pid)
                    
                    // If the element is a window, try to find a workspace to add it to
                    var windowCreated = false
                    
                    // Get windows for this app and assign new ones
                    let windows = WindowManager.shared.windowDiscovery.getWindowsForApplication(pid: pid)
                    for window in windows {
                        var windowId: CGWindowID = 0
                        if _AXUIElementGetWindow(window, &windowId) == .success,
                           let intId = Int(exactly: windowId),
                           WindowManager.shared.windowOwnership[intId] == nil {
                            // This is a new window, try to assign it to the active workspace
                            if let activeWorkspace = getActiveWorkspaceForApp(pid) {
                                activeWorkspace.adoptWindow(window)
                                windowCreated = true
                            }
                        }
                    }
                    
                    // If we created a new window, refresh everything
                    if windowCreated {
                        WindowManager.shared.refreshWindowsList()
                    }
                }
            }
        }
    }
    
    // Get the active workspace that contains a window from the given app
    private static func getActiveWorkspaceForApp(_ pid: pid_t) -> WorkspaceNode? {
        // First check currently active workspaces
        for monitor in WindowManager.shared.monitors {
            if let workspace = monitor.activeWorkspace {
                let windowNodes = workspace.getAllWindowNodes()
                let hasAppWindow = windowNodes.contains { node in
                    WindowManager.shared.getPID(for: node.window) == pid
                }
                
                if hasAppWindow {
                    return workspace
                }
            }
        }
        
        // If not found in active workspaces, look in all workspaces
        let workspaces = findWorkspacesContainingApp(pid)
        return workspaces.first
    }
    
    // Unregister from AX notifications for an application
    private static func unregisterFromWindowNotifications(for pid: pid_t) {
        guard let observer = observedApps[pid] else { return }
        
        // Remove observer from run loop and release
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        
        observedApps.removeValue(forKey: pid)
    }
    
    @MainActor
    static func initObserver() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.didHideApplicationNotification, object: nil, queue: .main, using: onHideApp)
        nc.addObserver(forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: onNotif)
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main, using: { notification in
            if let terminatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                let pid = terminatedApp.processIdentifier
                // Unregister from window notifications for this app
                unregisterFromWindowNotifications(for: pid)
                // Remove windows for this app
                WindowManager.shared.removeWindowsForApp(pid)
            }
        })
        
        // Add observer for window closed notification
        nc.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            WindowManager.shared.refreshWindowsList()
        }
        
        // Register for applications that are already running
        for runningApp in NSWorkspace.shared.runningApplications {
            if runningApp.activationPolicy == .regular {
                registerForWindowCreationNotifications(for: runningApp.processIdentifier)
            }
        }
    }
}
