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
    @State private var isCreatingWorkspace: Bool = false
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager = WindowManager.shared

    // Theme colors
    @AppStorage("accentColorName") private var accentColorName: String = "blue"

    var body: some Scene {
        // Menu Bar Extra
        MenuBarExtra {
            MenuBarView(
                openSettings: { showSettings() }
            )
        } label: {
            menuBarLabel
        }
    }

    var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "square.grid.2x2")
                .imageScale(.small)

            Text(
                windowManager.monitorWithMouse?.activeWorkspace?.title
                    ?? "Yuki"
            )
            .font(.system(size: 12))
        }
    }

    /// Show a window controller demonstrating the blurred window effect in a SwiftUI view
    private func showSettings() {

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
                    .accentColor(colorFromName(accentColorName))
                    .preferredColorScheme(.dark)
            ))
        window.title = "Yuki Settings"

        // The styleMask and transparent titlebar aren't required, but look better to me
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.center()

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let windowController = SettingsWindowController(window: window)
        windowController.showWindow(self)
        windowControllers.append(windowController)
    }

    /// Convert color name to NSColor
    private func colorFromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue": return Color.blue
        case "purple": return Color.purple
        case "pink": return Color.pink
        case "red": return Color.red
        case "orange": return Color.orange
        case "yellow": return Color.yellow
        case "green": return Color.green
        default: return Color.blue
        }
    }

}

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    override init(window: NSWindow?) {
        super.init(window: window)
        window?.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        // Remove self from the controllers array
        if let index = windowControllers.firstIndex(where: { $0 === self }) {
            windowControllers.remove(at: index)
        }
        ImageCacheManager.shared.clearMemoryCache()

        // Manually break potential reference cycles
        window?.contentViewController = nil
    }
}
