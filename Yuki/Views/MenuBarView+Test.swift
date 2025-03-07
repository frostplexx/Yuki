//
//  MenuBarView+WindowClassification.swift
//  Yuki
//
//  Created by Claude AI on 7/3/25.
//

import SwiftUI

/// Extensions to MenuBarView for window classification settings
extension MenuBarView {
    // Build a window classification settings panel
    func windowClassificationSettingsMenu() -> some View {
        Menu("Window Rules") {
            Toggle("Debug Window Classification", isOn: Binding(
                get: { WindowClassifier.shared.debugLoggingEnabled },
                set: { WindowClassifier.shared.debugLoggingEnabled = $0 }
            ))
            
            Divider()
            
            Button("Float Selected Window") {
                toggleSelectedWindowFloating()
            }
            
            Button("Add Current App to Float List") {
                addCurrentAppToFloatList()
            }
            
            Divider()
            
            Menu("Default Rules") {
                Button("Modal Windows") {
                    WindowClassifier.shared.addClassificationRule(ModalWindowRule())
                }
                
                Button("Small Windows (<400px)") {
                    WindowClassifier.shared.addClassificationRule(SmallWindowRule(maxWidth: 400, maxHeight: 400))
                }
                
                Button("Non-Resizable Windows") {
                    WindowClassifier.shared.addClassificationRule(UnresizableWindowRule())
                }
            }
            
            Button("Reset to Default Rules") {
                WindowClassifier.shared.clearCustomRules()
            }
        }
    }
    
    // Toggle floating state of the selected window
    private func toggleSelectedWindowFloating() {
        guard let workspace = windowManager.monitorWithMouse?.activeWorkspace else { return }
        
        // Find the currently focused window
        let windowNodes = workspace.getAllWindowNodes()
        let focusedNode = windowNodes.first { node in
            node.window.get(Ax.isFocused) ?? false
        }
        
        guard let selectedNode = focusedNode else {
            print("No focused window found")
            return
        }
        
        // Toggle floating state
        let isNowFloating = selectedNode.toggleFloating()
        print("Window '\(selectedNode.title ?? "Untitled")' is now \(isNowFloating ? "floating" : "tiled")")
        
        // Reapply tiling
        workspace.applyTilingWithClassification()
    }
    
    // Add the current application to the floating list
    private func addCurrentAppToFloatList() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontmostApp.bundleIdentifier else {
            print("No frontmost application found")
            return
        }
        
        WindowClassifier.shared.addFloatingAppBundleIDs([bundleID])
        print("Added \(frontmostApp.localizedName ?? "Unknown") (\(bundleID)) to floating app list")
        
        // Reapply tiling to update the layout
        if let workspace = windowManager.monitorWithMouse?.activeWorkspace {
            workspace.applyTilingWithClassification()
        }
    }
}
