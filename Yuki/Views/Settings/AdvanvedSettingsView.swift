// AdvanvedSettingsView.swift
// Advanced configuration options

import SwiftUI

struct AdvancedSettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Config File Location
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Configuration")
                            .font(.headline)
                        
                        Text("Settings are stored in ~/.config/Yuki/settings.json")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Button("Open in Finder") {
                            let url = FileManager.default.homeDirectoryForCurrentUser
                                .appendingPathComponent(".config/Yuki")
                            NSWorkspace.shared.selectFile(
                                url.appendingPathComponent("settings.json").path,
                                inFileViewerRootedAtPath: url.path
                            )
                        }
                        
                        Button("Reset All Settings", role: .destructive) {
                            //                            settings.resetToDefaults()
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }
                
                // Debugging
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Debugging")
                            .font(.headline)
                        
                        Toggle("Enable Debug Logging", isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "EnableDebugLogging") },
                            set: { UserDefaults.standard.set($0, forKey: "EnableDebugLogging") }
                        ))
                        
                        Button("Export Debug Log") {
                            exportDebugLog()
                        }
                    }
                    .padding()
                }
                
                // System Integration
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("System Integration")
                            .font(.headline)
                        
                        Button("Open Accessibility Preferences") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                        
                        Toggle("Launch at Login", isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "LaunchAtLogin") },
                            set: {
                                UserDefaults.standard.set($0, forKey: "LaunchAtLogin")
                                setLaunchAtLogin($0)
                            }
                        ))
                    }
                    .padding()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func exportDebugLog() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "yuki_debug.log"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // Get debug log and save it
                let log = "Debug log content" // Replace with actual debug log
                try? log.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        // Implement launch at login logic
        // You
        
    }
}
