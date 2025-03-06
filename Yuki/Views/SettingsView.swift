//
//  SettingsView.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var showingPermissionView = false
    @State private var selectedTab = 0
    
    var body: some View {
        if showingPermissionView {
            AccessibilityPermissionView()
        } else {
            TabView(selection: $selectedTab) {
                // General settings
                generalSettingsView
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                    .tag(0)
                
                // Tiling settings
                TilingSettingsView()
                    .tabItem {
                        Label("Tiling", systemImage: "square.grid.2x2")
                    }
                    .tag(1)
                
                // Workspaces
                workspaceSettingsView
                    .tabItem {
                        Label("Workspaces", systemImage: "rectangle.3.group")
                    }
                    .tag(2)
                
                // Hotkeys
                hotkeySettingsView
                    .tabItem {
                        Label("Hotkeys", systemImage: "keyboard")
                    }
                    .tag(3)
                
                // About
                aboutView
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }
                    .tag(4)
            }
            .padding()
            .frame(width: 500, height: 400)
            .onAppear {
                DispatchQueue.main.async {
                    showingPermissionView = !AXIsProcessTrusted()
                }
            }
        }
    }
    
    // MARK: - Tab Views
    
    var generalSettingsView: some View {
        VStack {
            Text("General Settings")
                .font(.title)
                .padding(.bottom, 20)
            
            Button("Test Accessibility") {
                if !AXIsProcessTrusted() {
                    showingPermissionView = true
                } else {
                    print("Accessibility permissions granted!")
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    var workspaceSettingsView: some View {
        VStack {
            Text("Workspace Management")
                .font(.title)
                .padding(.bottom, 20)
            
            Text("Configure your workspaces here")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
    
    var hotkeySettingsView: some View {
        VStack {
            Text("Hotkey Configuration")
                .font(.title)
                .padding(.bottom, 20)
            
            Text("Configure keyboard shortcuts here")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
    
    var aboutView: some View {
        VStack {
            Text("About Yuki")
                .font(.title)
                .padding(.bottom, 20)
            
            Text("Yuki is a tiling window manager for macOS")
                .foregroundColor(.secondary)
            
            Text("Version 1.0")
                .padding(.top, 10)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
