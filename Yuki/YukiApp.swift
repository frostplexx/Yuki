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
    @State private var newWorkspaceName: String = ""
    @State private var isCreatingWorkspace: Bool = false
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var windowManager = WindowManager.shared

    var body: some Scene {
        // Menu Bar Extra
        MenuBarExtra {
            MenuBarView(
                openSettings: { openWindow(id: "settingsWindow") }
            )
        } label: {
            Text(
                windowManager.monitorWithMouse?.activeWorkspace?.title ?? "Unknow Workspace"
            )
        }

        // Settings window
        Window("Settings", id: "settingsWindow") {
            SettingsView()
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    // Refresh window tree when settings appear
                    //                    WindowManager.shared.refreshWindows()
                }
                .onDisappear {
                    NSApp.setActivationPolicy(.accessory)
                    NSApp.deactivate()
                }
        }
    }

}
