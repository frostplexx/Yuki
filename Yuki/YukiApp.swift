//
//  YukiApp.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import SwiftUI

private var windowControllers: [NSWindowController] = []

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
                openSettings: { showSettings() }
            )
            .onAppear {
                showSettings()
            }
        } label: {
            Text(
                windowManager.monitorWithMouse?.activeWorkspace?.title
                    ?? "Unknow Workspace"
            )
        }
    }

    /// Show a window controller demonstrating the blurred window effect in a SwiftUI view
    private func showSettings() {
        var pos: NSPoint = NSPoint()

        let windowSize: (CGFloat, CGFloat) = (1000.0, 650.0)

        let window = NSWindow(
            contentViewController: NSHostingController(
                rootView: SettingsView()
                    .frame(
                        minWidth: windowSize.0, maxWidth: windowSize.0,
                        minHeight: windowSize.1,
                        maxHeight: windowSize.1
                    )
                    .background(VisualEffectView().ignoresSafeArea())
                    .preferredColorScheme(.dark)
            ))
        window.title = "Yuki Settings"

        // The styleMask and transparent titlebar aren't required, but look better to me
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true

        let screen = WindowManager.shared.monitorWithMouse

        pos.x = (screen?.frame.size.width ?? 0.0) - windowSize.0

        pos.y = (screen?.frame.size.height ?? 0.0) - windowSize.1

        window.setFrame(
            CGRectMake(
                pos.x / 2,
                pos.y / 2,
                windowSize.0,
                windowSize.1), display: true)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let windowController = NSWindowController(window: window)
        windowController.showWindow(self)
        windowControllers.append(windowController)
    }

}
