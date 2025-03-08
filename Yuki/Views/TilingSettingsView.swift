//
//  TilingSettingsView.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import SwiftUI

/// View for configuring tiling settings
struct TilingSettingsView: View {
    @ObservedObject private var windowManager = WindowManager.shared
    @State private var selectedWorkspaceIndex = 0
    @State private var windowGap: Double = 8.0
    @State private var outerGap: Double = 8.0
    @State private var allowResize = false
    @State private var allowMove = false
    @State private var selectedModeIndex = 0
    @State private var tilingRefreshRate: Double = 0.1 // Default 100ms throttle interval
    
    private let tilingModes = ["Float", "HStack", "VStack", "ZStack", "BSP"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tiling Settings")
                .font(.title)
                .padding(.bottom, 10)
            
            // Workspace selection
            VStack(alignment: .leading) {
                Text("Workspace").font(.headline)
                Picker("Workspace", selection: $selectedWorkspaceIndex) {
                    ForEach(0..<workspaces.count, id: \.self) { index in
                        Text(workspaces[index].title ?? "Untitled").tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedWorkspaceIndex) { _ in
                    loadWorkspaceSettings()
                }
            }
            
            // Tiling mode selection
            VStack(alignment: .leading) {
                Text("Tiling Mode").font(.headline)
                Picker("Tiling Mode", selection: $selectedModeIndex) {
                    ForEach(0..<tilingModes.count, id: \.self) { index in
                        Text(tilingModes[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedModeIndex) { newValue in
                    applyTilingMode(tilingModes[newValue].lowercased())
                }
            }
            
            // Gap settings
            VStack(alignment: .leading) {
                Text("Window Gap").font(.headline)
                HStack {
                    Slider(value: $windowGap, in: 0...30, step: 1)
                        .frame(width: 200)
                    Text("\(Int(windowGap))")
                        .frame(width: 30)
                }
                .onChange(of: windowGap) { _ in
                    applyGapSettings()
                }
            }
            
            VStack(alignment: .leading) {
                Text("Outer Gap").font(.headline)
                HStack {
                    Slider(value: $outerGap, in: 0...30, step: 1)
                        .frame(width: 200)
                    Text("\(Int(outerGap))")
                        .frame(width: 30)
                }
                .onChange(of: outerGap) { _ in
                    applyGapSettings()
                }
            }
            
            // Performance settings
            VStack(alignment: .leading) {
                Text("Performance").font(.headline)
                HStack {
                    Text("Refresh Interval")
                    Slider(value: $tilingRefreshRate, in: 0.05...0.5, step: 0.05)
                        .frame(width: 150)
                    Text("\(Int(tilingRefreshRate * 1000))ms")
                        .frame(width: 60)
                }
                .onChange(of: tilingRefreshRate) { _ in
                    applyPerformanceSettings()
                }
            }
            
            // Advanced options
            VStack(alignment: .leading) {
                Text("Advanced Options").font(.headline)
                
                Toggle("Allow Resize", isOn: $allowResize)
                    .onChange(of: allowResize) { _ in
                        applyAdvancedSettings()
                    }
                
                Toggle("Allow Move", isOn: $allowMove)
                    .onChange(of: allowMove) { _ in
                        applyAdvancedSettings()
                    }
            }
            
            Spacer()
            
            // Action buttons
            HStack {
                Button("Apply to All Workspaces") {
                    applyToAllWorkspaces()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                
                Button("Clear Caches") {
                    clearCaches()
                }
            }
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            loadWorkspaceSettings()
        }
    }
    
    // MARK: - Helper Methods
    
    private var workspaces: [WorkspaceNode] {
        return windowManager.monitors.flatMap { $0.workspaces }
    }
    
    private var selectedWorkspace: WorkspaceNode? {
        guard selectedWorkspaceIndex < workspaces.count else { return nil }
        return workspaces[selectedWorkspaceIndex]
    }
    
    private func loadWorkspaceSettings() {
        guard let workspace = selectedWorkspace else { return }
        
        // Load current settings from the workspace
//        let config = workspace.tilingEngine.config
//        windowGap = Double(config.windowGap)
//        outerGap = Double(config.outerGap)
//        allowResize = config.allowResize
//        allowMove = config.allowMove
        
        // Set the tiling mode
//        let modeName = workspace.tilingEngine.currentModeName
//        if let index = tilingModes.firstIndex(where: { $0.lowercased() == modeName }) {
//            selectedModeIndex = index
//        } else {
//            selectedModeIndex = 0 // Default to Float
//        }
        
        // Load throttle interval
//        if let engine = workspace.tilingEngine {
//            tilingRefreshRate = engine.tilingThrottleInterval
//        }
    }
    
    private func applyTilingMode(_ modeName: String) {
        guard let workspace = selectedWorkspace else { return }
//        workspace.setTilingMode(modeName)
    }
    
    private func applyGapSettings() {
        guard let workspace = selectedWorkspace else { return }
        
//        var config = workspace.tilingEngine.config
//        config.windowGap = CGFloat(windowGap)
//        config.outerGap = CGFloat(outerGap)
//        workspace.setTilingConfiguration(config)
    }
    
    private func applyAdvancedSettings() {
        guard let workspace = selectedWorkspace else { return }
        
//        var config = workspace.tilingEngine.config
//        config.allowResize = allowResize
//        config.allowMove = allowMove
//        workspace.setTilingConfiguration(config)
    }
    
    private func applyPerformanceSettings() {
        guard let workspace = selectedWorkspace else { return }
        
//        if let engine = workspace.tilingEngine {
//            engine.tilingThrottleInterval = tilingRefreshRate
//        }
    }
    
    private func applyToAllWorkspaces() {
        let config = TilingConfiguration(
            windowGap: CGFloat(windowGap),
            outerGap: CGFloat(outerGap),
            allowResize: allowResize,
            allowMove: allowMove
        )
        
//        windowManager.setGlobalTilingConfiguration(config)
//        windowManager.setGlobalTilingMode(tilingModes[selectedModeIndex].lowercased())
        
        // Apply performance settings to all workspaces
//        for monitor in windowManager.monitors {
//            for workspace in monitor.workspaces {
//                if let engine = workspace.tilingEngine {
//                    engine.tilingThrottleInterval = tilingRefreshRate
//                }
//            }
//        }
    }
    
    private func resetToDefaults() {
        windowGap = 8.0
        outerGap = 8.0
        allowResize = false
        allowMove = false
        selectedModeIndex = 0 // Float
        tilingRefreshRate = 0.1 // Reset to 100ms
        
        applyGapSettings()
        applyAdvancedSettings()
        applyTilingMode("float")
        applyPerformanceSettings()
    }
    
    private func clearCaches() {
        // Clear window classification caches in all tiling engines
//        for monitor in windowManager.monitors {
//            for workspace in monitor.workspaces {
//                workspace.tilingEngine?.clearCache()
//            }
//        }
    }
}

#Preview {
    TilingSettingsView()
}
