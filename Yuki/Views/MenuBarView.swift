//
//  MenuBarView.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import SwiftUI

struct MenuBarView: View {
    // Required properties
    @ObservedObject var windowManager: WindowManager
    @Binding var isCreatingWorkspace: Bool
    var openSettings: () -> Void
    
    var body: some View {
        Group {
            // Current monitor section
            if let currentMonitor = windowManager.monitorWithMouse {
                currentMonitorSection(monitor: currentMonitor)
            }
            
            // All workspaces section
            allWorkspacesSection()
            
            // Layout actions
            if let selectedWorkspace = windowManager.selectedWorkspace {
                layoutActionsSection(workspace: selectedWorkspace)
            }
            
            // Settings and utilities
            utilitiesSection()
        }
    }
    
    // MARK: - Section Views
    
    private func currentMonitorSection(monitor: Monitor) -> some View {
        Group {
            Text("Current Monitor: \(monitor.name)")
                .font(.headline)
                .padding(.top, 5)
                .padding(.bottom, 2)
            
            ForEach(monitor.workspaces) { workspace in
                Button(workspace.displayName) {
                    windowManager.selectWorkspace(workspace)
                }
            }
            
            Button("New Workspace on This Monitor...") {
                isCreatingWorkspace = true
            }
            
            Divider()
        }
    }
    
    private func allWorkspacesSection() -> some View {
        Group {
            Text("All Workspaces")
                .font(.headline)
                .padding(.top, 5)
                .padding(.bottom, 2)
            
            ForEach(windowManager.workspaces) { workspace in
                Button(workspace.displayName) {
                    windowManager.selectWorkspace(workspace)
                }
            }
            
            Divider()
        }
    }
    
    private func layoutActionsSection(workspace: Workspace) -> some View {
        Group {
            Text("Layout Actions")
                .font(.headline)
                .padding(.top, 5)
                .padding(.bottom, 2)
            
            Button("Toggle Tiling") {
                windowManager.toggleAutoTiling()
            }
            
            Button("Cycle Next Tiling Mode") {
                windowManager.cycleAndApplyNextTilingMode()
            }
            
            Button("Apply Current Tiling Mode") {
                windowManager.applyCurrentTiling()
            }
            
            
            Divider()
        }
    }
    
    private func utilitiesSection() -> some View {
        Group {
            Button("Open Settings") {
                openSettings()
            }.keyboardShortcut(",")
            
            Divider()
            
            Button("Debug Print Window Tree") {
                windowManager.printDebugInfo()
            }.keyboardShortcut("d", modifiers: [.command, .shift])
            
            Button("Refresh Windows") {
                windowManager.refreshWindows()
            }.keyboardShortcut("r", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
        }
    }
}
