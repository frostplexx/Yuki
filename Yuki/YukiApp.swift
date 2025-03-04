//
//  YukiApp.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import SwiftUI

@main
struct YukiApp: App {
    // Connect the AppDelegate to the SwiftUI lifecycle
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Application state
    @StateObject private var windowManager = WindowManager()
    @State private var newWorkspaceName: String = ""
    @State private var isCreatingWorkspace: Bool = false
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        // Menu Bar Extra
        MenuBarExtra {
            MenuBarView(
                windowManager: windowManager,
                isCreatingWorkspace: $isCreatingWorkspace,
                openSettings: { openWindow(id: "settingsWindow") }
            )
        } label: {
            Text(windowManager.selectedWorkspace?.displayName ?? "Unknown Workspace")
        }
        
//        // New workspace dialog
//        if isCreatingWorkspace {
//            Window("New Workspace", id: "newWorkspaceWindow") {
//                WorkspaceCreationView(
//                    workspaceName: $newWorkspaceName,
//                    isShowing: $isCreatingWorkspace,
//                    windowManager: windowManager
//                )
//            }
//        }
        
        // Settings window
        Window("Settings", id: "settingsWindow") {
            SettingsView()
                .environmentObject(windowManager)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    // Refresh window tree when settings appear
                    windowManager.refreshWindows()
                }
                .onDisappear {
                    NSApp.setActivationPolicy(.accessory)
                    NSApp.deactivate()
                }
        }
    }
}

