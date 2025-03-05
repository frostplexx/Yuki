//
//  MenuBarView.swift
//  Yuki
//
//  Created by Claude AI on 6/3/25.
//

import SwiftUI

struct MenuBarView: View {
    // Required properties
    @ObservedObject var windowManager: WindowManager
    @Binding var isCreatingWorkspace: Bool
    var openSettings: () -> Void
    
    // Local state
    @State private var isPinningEnabled: Bool = false
    
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
            
            // Window pinning section
            windowPinningSection()
            
            // Settings and utilities
            utilitiesSection()
        }
        .onAppear {
            // Initialize state from window manager
            isPinningEnabled = windowManager.windowPinningEnabled
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
            
            let currentMode = TilingEngine.shared.currentMode
            Button("Current Mode: \(currentMode.description)") {
                windowManager.cycleAndApplyNextTilingMode()
                
                // Update pinning state based on new mode
                windowManager.handleTilingModeChange()
                isPinningEnabled = windowManager.windowPinningEnabled
            }
            
            Button("Apply Current Tiling") {
                windowManager.applyCurrentTilingWithPinning()
            }
            
            Divider()
        }
    }
    
    private func windowPinningSection() -> some View {
        Group {
            Text("Window Control")
                .font(.headline)
                .padding(.top, 5)
                .padding(.bottom, 2)
            
            Toggle("Lock Windows in Place", isOn: $isPinningEnabled)
                .onChange(of: isPinningEnabled) { newValue in
                    if newValue {
                        windowManager.enableWindowPinning()
                    } else {
                        windowManager.disableWindowPinning()
                    }
                }
                .disabled(TilingEngine.shared.currentMode == .float)
                .padding(.horizontal, 16)
            
            Button("Force Window Refresh") {
                windowManager.windowObserver?.forceWindowRefresh()
                
                // If not in float mode, reapply tiling
                if TilingEngine.shared.currentMode != .float {
                    windowManager.applyCurrentTilingWithPinning()
                }
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

