//
//  MenuBarView.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import SwiftUI

struct MenuBarView: View {
    var openSettings: () -> Void
    
    // Add state observation for WindowManager
    @ObservedObject var windowManager = WindowManager.shared
    @State private var debugClassification = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Group monitors and their workspaces
            ForEach(windowManager.monitors) { monitor in
                MonitorSection(monitor: monitor)
            }
            
            Button {
                windowManager.monitorWithMouse?.activeWorkspace?.applyTiling()
            } label: {
                Text("Apply Tiling")
            }
            
            // Window classification menu
            windowClassificationSettingsMenu()
            
            Divider()
            
            Button {
                windowManager.printDebugInfo()
            } label: {
                Text("Debug Info")
            }
            
            Button("Inspect Windows") {
                inspectAllWindows()
            }

            
            Button {
                windowManager.discoverAndAssignWindows()
            } label: {
                Text("Refresh Windows")
            }
            
            // Settings button
            Button(action: openSettings) {
                Label("Settings", systemImage: "gear")
            }
            .help("Open Settings")
            .keyboardShortcut(",")
        }
    }
    
    
    func inspectAllWindows() {
        guard let workspace = windowManager.monitorWithMouse?.activeWorkspace else { return }
        let allWindows = workspace.getAllWindowNodes()
        
        print("\n--- WINDOW CLASSIFICATION INSPECTION ---")
        for (i, window) in allWindows.enumerated() {
            let shouldFloat = WindowClassifier.shared.shouldWindowFloat(window.window)
            let title = window.title ?? "Untitled"
            var pid: pid_t = 0
            AXUIElementGetPid(window.window, &pid)
            let app = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "Unknown"
            
            print("\(i+1). \(title) (\(app)): \(shouldFloat ? "FLOATING" : "TILED")")
        }
        print("-------------------------------------\n")
    }
}

// Separate component for monitor and its workspaces
struct MonitorSection: View {
    @ObservedObject var monitor: Monitor
    
    var body: some View {
        VStack {
            Text(monitor.name)
                .font(.system(size: 12, weight: .medium))
                .opacity(0.5)
            
            ForEach(monitor.workspaces, id: \.id) { workspace in
                Button {
                    workspace.activate()
                } label: {
                    Text(workspace.title ?? "(Unknown)")
                }
            }
        }
    }
}
